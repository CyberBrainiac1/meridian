import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut(error: String?)
        /// Role-gated: only owner/admin/caregiver see Care's full feature
        /// set (api-contract.md roles reference). A signed-in user with no
        /// facility_members row, or a family-only account, lands here.
        case notAuthorized
        case signedIn(facilityId: String, facilityName: String, role: FacilityRole)
    }

    @Published private(set) var state: State = .loading
    @Published var email = ""
    @Published var password = ""
    @Published var isSubmitting = false

    private let client = SupabaseManager.client

    func start() async {
        guard SupabaseConfig.isConfigured else {
            state = .signedOut(error: nil)
            return
        }
        for await (_, session) in client.auth.authStateChanges {
            if let session {
                await resolveFacility(userId: session.user.id)
            } else {
                state = .signedOut(error: nil)
            }
        }
    }

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            state = .signedOut(error: "Enter your email and password.")
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            await resolveFacility(userId: session.user.id)
        } catch {
            state = .signedOut(error: "That email and password combination wasn't recognized.")
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        state = .signedOut(error: nil)
    }

    private struct FacilityRow: Decodable {
        let facilityId: String
        let role: FacilityRole
        let facilities: FacilityName?

        struct FacilityName: Decodable {
            let displayName: String
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }

        enum CodingKeys: String, CodingKey {
            case facilityId = "facility_id"
            case role, facilities
        }
    }

    /// Role gate: Care is owner/admin/caregiver only (viewer and family
    /// accounts are valid Supabase users but have no place in this app —
    /// viewer belongs on Insights, family belongs in Meridian Family).
    private func resolveFacility(userId: UUID) async {
        do {
            let rows: [FacilityRow] = try await client
                .from("facility_members")
                .select("facility_id, role, facilities(display_name)")
                .eq("user_id", value: userId)
                .execute()
                .value

            guard let membership = rows.first(where: { [.owner, .admin, .caregiver].contains($0.role) })
            else {
                state = .notAuthorized
                return
            }

            state = .signedIn(
                facilityId: membership.facilityId,
                facilityName: membership.facilities?.displayName ?? membership.facilityId,
                role: membership.role
            )
        } catch {
            state = .signedOut(error: "Couldn't load your facility. Try signing in again.")
        }
    }
}
