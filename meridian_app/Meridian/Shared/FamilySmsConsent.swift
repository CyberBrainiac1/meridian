import Foundation
import Supabase

/// One `public.family_sms_preferences` row, read back so the settings screen
/// can show the number that is actually on file rather than whatever was last
/// typed. RLS already scopes selects to `family_user_id = auth.uid()`, so no
/// filter on the caller is needed or possible here.
struct FamilySmsPreference: Decodable, Equatable {
    let residentId: String
    let phoneE164: String
    let consentStatus: String

    var isOptedIn: Bool { consentStatus == "opted_in" }

    enum CodingKeys: String, CodingKey {
        case residentId = "resident_id"
        case phoneE164 = "phone_e164"
        case consentStatus = "consent_status"
    }
}

enum FamilySmsConsentError: LocalizedError, Equatable {
    case emptyPhone
    case missingPlus
    case leadingZero
    case notDigits
    case wrongLength
    case noFamilyLink
    case noActiveConsent
    case rejectedByServer
    case unknown

    var errorDescription: String? {
        switch self {
        case .emptyPhone:
            return "Enter the mobile number that should receive texts."
        case .missingPlus:
            return "Start with a plus sign and the country code, like +14155550123."
        case .leadingZero:
            return "The country code can't start with a zero. A US number looks like +14155550123."
        case .notDigits:
            return "Use digits only after the plus sign — no letters."
        case .wrongLength:
            return "That number needs between 8 and 15 digits after the plus sign."
        case .noFamilyLink:
            return "This account isn't linked to that resident, so texts can't be set up. Ask the facility to check the link."
        case .noActiveConsent:
            return "Text alerts were already off for this resident."
        case .rejectedByServer:
            return "The facility's records rejected that number. Check it and try again."
        case .unknown:
            return "Couldn't save that just now. Check the connection and try again."
        }
    }
}

/// Read/write path for a family member's own SMS escalation consent.
///
/// Closes a gap the app already promised to fill: `FamHelpTopic.privacy`
/// tells families "Turn SMS escalation on or off here at any time", and until
/// now there was no such control anywhere in the app. Writes go exclusively
/// through `set_my_family_sms_consent`, never straight to the table — the RPC
/// is what writes the immutable consent-audit row, and `authenticated` has no
/// insert/update grant on `family_sms_preferences` anyway.
enum FamilySmsConsentService {
    /// Recorded on every consent event so an auditor can tell a number set in
    /// this screen from one set by facility staff.
    static let consentSource = "family_app_settings"
    static let consentTextVersion = "2026-08-v1"

    /// The same expression as the `phone_e164` CHECK constraint on
    /// `public.family_sms_preferences` and the guard inside
    /// `set_my_family_sms_consent`. Validated here as well so a mistyped
    /// number comes back as a sentence rather than as a Postgres error code.
    private static let e164Pattern = "^\\+[1-9][0-9]{7,14}$"

    /// Formatting a human would reasonably type is not an error — spaces,
    /// dashes, dots and brackets are stripped before validating rather than
    /// rejected.
    static func normalize(_ raw: String) -> String {
        raw.filter { !" -().\u{00A0}".contains($0) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validate(_ raw: String) -> Result<String, FamilySmsConsentError> {
        let candidate = normalize(raw)
        guard !candidate.isEmpty else { return .failure(.emptyPhone) }
        guard candidate.hasPrefix("+") else { return .failure(.missingPlus) }

        let digits = String(candidate.dropFirst())
        guard !digits.isEmpty else { return .failure(.wrongLength) }
        guard digits.allSatisfy(\.isNumber) else { return .failure(.notDigits) }
        guard !digits.hasPrefix("0") else { return .failure(.leadingZero) }
        guard digits.count >= 8, digits.count <= 15 else { return .failure(.wrongLength) }
        guard candidate.range(of: e164Pattern, options: .regularExpression) != nil else {
            return .failure(.rejectedByServer)
        }
        return .success(candidate)
    }

    /// Active consents only. Revoked rows are retained as audit history, so
    /// reading them back would show a number that is no longer in use.
    static func loadActive() async -> [String: FamilySmsPreference] {
        do {
            let rows: [FamilySmsPreference] = try await SupabaseManager.client
                .from("family_sms_preferences")
                .select("resident_id,phone_e164,consent_status")
                .eq("consent_status", value: "opted_in")
                .execute()
                .value
            return Dictionary(rows.map { ($0.residentId, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            return [:]
        }
    }

    static func setConsent(
        residentId: String,
        phoneE164: String?,
        optIn: Bool
    ) async -> Result<Void, FamilySmsConsentError> {
        // Opting out still has to send a phone number: the RPC's signature is
        // non-null on every parameter. It is ignored on the revoke path, which
        // matches on the caller's active row instead.
        let args = SetFamilySmsConsentArgs(
            pResidentId: residentId,
            pPhoneE164: phoneE164 ?? "+10000000000",
            pOptIn: optIn,
            pConsentSource: consentSource,
            pConsentTextVersion: consentTextVersion
        )
        do {
            try await SupabaseManager.client
                .rpc("set_my_family_sms_consent", params: args)
                .execute()
            return .success(())
        } catch let error as PostgrestError {
            // Mirrors the errcodes raised inside
            // supabase/migrations/20260807000100_family_sms_escalation.sql.
            switch error.code {
            case "42501": return .failure(.noFamilyLink)
            case "22023": return .failure(.rejectedByServer)
            case "P0002": return .failure(.noActiveConsent)
            default: return .failure(.unknown)
            }
        } catch {
            return .failure(.unknown)
        }
    }
}

/// RPC args for `public.set_my_family_sms_consent`.
struct SetFamilySmsConsentArgs: Encodable {
    let pResidentId: String
    let pPhoneE164: String
    let pOptIn: Bool
    let pConsentSource: String
    let pConsentTextVersion: String

    enum CodingKeys: String, CodingKey {
        case pResidentId = "p_resident_id"
        case pPhoneE164 = "p_phone_e164"
        case pOptIn = "p_opt_in"
        case pConsentSource = "p_consent_source"
        case pConsentTextVersion = "p_consent_text_version"
    }
}
