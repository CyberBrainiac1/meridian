import Foundation
import Supabase

enum MedicationActionError: LocalizedError {
    case notAuthorized
    case invalidStatus
    case notFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "You don't have permission to record medications."
        case .invalidStatus: return "That isn't a valid outcome for this dose."
        case .notFound: return "This medication is no longer on the resident's chart."
        case .unknown: return "Something went wrong. Try again."
        }
    }
}

private struct RecordAdministrationArgs: Encodable {
    let pMedicationId: String
    let pScheduledFor: String
    let pStatus: String
    let pNote: String?

    enum CodingKeys: String, CodingKey {
        case pMedicationId = "p_medication_id"
        case pScheduledFor = "p_scheduled_for"
        case pStatus = "p_status"
        case pNote = "p_note"
    }
}

/// Single write path for medication administration — mirrors
/// record_medication_administration's error codes. Every surface that records
/// a dose (resident detail screen, notification action) goes through here, so
/// the MAR never diverges depending on where the caregiver tapped.
enum MedicationActionService {
    static func record(
        medicationId: String,
        scheduledFor: Date,
        status: MedicationDoseStatus,
        note: String? = nil
    ) async -> Result<Void, MedicationActionError> {
        // 'outstanding' is a derived display state, never something we write:
        // the absence of a row is what makes a dose outstanding.
        guard status != .outstanding else { return .failure(.invalidStatus) }

        let args = RecordAdministrationArgs(
            pMedicationId: medicationId,
            pScheduledFor: ISO8601DateFormatter().string(from: scheduledFor),
            pStatus: status.rawValue,
            pNote: note?.isEmpty == false ? note : nil
        )
        do {
            try await SupabaseManager.client
                .rpc("record_medication_administration", params: args)
                .execute()
            return .success(())
        } catch let error as PostgrestError {
            switch error.code {
            case "42501": return .failure(.notAuthorized)
            case "22023": return .failure(.invalidStatus)
            case "P0002": return .failure(.notFound)
            default: return .failure(.unknown)
            }
        } catch {
            return .failure(.unknown)
        }
    }
}
