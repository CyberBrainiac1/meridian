import Foundation
import Supabase

/// Which interface a signed-in account belongs to.
///
/// The three used to be separate apps with separate binaries; the routing
/// below is the same three role gates each of them ran at launch, now
/// evaluated in one place and in a deliberate order.
enum MeridianSurface: Equatable {
    case care(facilityId: String, facilityName: String, role: CareFacilityRole)
    case hub(profile: HubProfile)
    case family(residents: [FamilyLinkedResident])
}

@MainActor
final class AuthViewModel: ObservableObject {
    enum Step: Equatable {
        /// Deciding whether there is already a session. Distinct from
        /// `choosingFacility` so a returning user does not see the facility
        /// picker flash on screen for a moment before being thrown into their
        /// own interface — which reads as the app changing its mind.
        case restoring
        /// Nothing chosen yet — pick a building.
        case choosingFacility
        /// Facility chosen, waiting on a name and password.
        case signingIn(facility: MeridianFacility)
        /// Signed in, but the account matches none of the three surfaces.
        case notAuthorized
        case ready(MeridianSurface)
    }

    @Published private(set) var step: Step = .restoring
    @Published private(set) var facilities: [MeridianFacility] = []
    @Published private(set) var isLoadingFacilities = false
    @Published private(set) var isSubmitting = false
    @Published var name = ""
    @Published var password = ""
    @Published var errorMessage: String?

    private let client = SupabaseManager.client

    /// Restores a previous session on launch so a resident is not asked to
    /// sign in again every time the Hub is opened.
    func start() async {
        guard SupabaseConfig.isConfigured else {
            errorMessage = "This build has no Supabase project configured yet. A staff member needs to finish setting it up."
            step = .choosingFacility
            return
        }

        // Both are network round trips and neither depends on the other, so
        // they overlap rather than queue. Serialising them doubled the time
        // spent on the launch splash for no reason.
        async let facilitiesLoaded: Void = loadFacilities()
        let hasSession = (try? await client.auth.session) != nil
        await facilitiesLoaded

        if hasSession {
            await resolveSurface()
        } else {
            step = .choosingFacility
        }
    }

    func loadFacilities() async {
        isLoadingFacilities = true
        defer { isLoadingFacilities = false }
        do {
            let rows: [MeridianFacility] = try await client
                .rpc("list_facilities")
                .execute()
                .value
            facilities = rows
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load the list of facilities. Check the connection and try again."
        }
    }

    func choose(_ facility: MeridianFacility) {
        guard facility.hasAccounts else { return }
        name = ""
        password = ""
        errorMessage = nil
        step = .signingIn(facility: facility)
    }

    func backToFacilities() {
        name = ""
        password = ""
        errorMessage = nil
        step = .choosingFacility
    }

    /// Supabase Auth is email/password underneath. Nobody types an email:
    /// `Lin_Nakamura` at facility `meridian-demo` becomes
    /// `lin_nakamura@meridian-demo.meridian.invalid`. Normalising here means a
    /// stray capital, a space instead of an underscore, or trailing
    /// whitespace all still sign in — none of those are the user's mistake to
    /// pay for on a shared device.
    static func email(for rawName: String, facilityId: String) -> String {
        let normalized = rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        return "\(normalized)@\(facilityId).meridian.invalid"
    }

    func signIn() async {
        guard case .signingIn(let facility) = step else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your name and password."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            try await client.auth.signIn(
                email: Self.email(for: trimmedName, facilityId: facility.id),
                password: password
            )
            await resolveSurface()
        } catch {
            // Deliberately does not say which half was wrong — but also does
            // not imply the facility choice was the problem, since that is
            // the one thing they can see is correct.
            errorMessage = "That name and password didn't match an account at \(facility.displayName)."
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        name = ""
        password = ""
        errorMessage = nil
        step = .choosingFacility
    }

    /// Order matters. A family account also carries a `facility_members` row
    /// with role `family`, so checking membership first would route every
    /// relative into the caregiver interface. Hub is checked first because a
    /// bound device is the most specific claim of the three.
    private func resolveSurface() async {
        // Each decode is bound to an explicitly-typed local first. Chaining
        // `.execute().value.first` instead leaves `.value` with nothing to
        // infer from and it resolves to Void.

        // 1. A resident's own device.
        let profiles: [HubProfile]? = try? await client
            .from("resident_hub_profile")
            .select()
            .execute()
            .value
        if let profile = profiles?.first {
            step = .ready(.hub(profile: profile))
            return
        }

        // 2. Staff. `family` is excluded here on purpose — see above.
        let memberships: [CareMembership]? = try? await client
            .from("facility_members")
            .select("facility_id, role")
            .execute()
            .value
        if let membership = memberships?.first(where: { $0.role.isCareTeam }) {
            let facilityName = facilities.first { $0.id == membership.facilityId }?.displayName
                ?? membership.facilityId
            step = .ready(.care(
                facilityId: membership.facilityId,
                facilityName: facilityName,
                role: membership.role
            ))
            return
        }

        // 3. A relative.
        let residents: [FamilyLinkedResident]? = try? await client
            .from("family_linked_residents")
            .select()
            .execute()
            .value
        if let residents, !residents.isEmpty {
            step = .ready(.family(residents: residents))
            return
        }

        step = .notAuthorized
    }
}

/// One `public.facility_members` row, used only for routing.
private struct CareMembership: Decodable {
    let facilityId: String
    let role: CareFacilityRole

    enum CodingKeys: String, CodingKey {
        case facilityId = "facility_id"
        case role
    }
}
