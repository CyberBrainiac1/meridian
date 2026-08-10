import Foundation
import Supabase

/// Same shape as Care's and Family's AuthViewModel, with one difference in
/// what "authorized" means: this app is bound to a *device*, not a person. A
/// Hub sign-in is done once by a caregiver standing in the room, and from then
/// on the phone stays signed in and sits with the resident.
@MainActor
final class AuthViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut(error: String?)
        /// Role gate: an account with no `resident_hub_profile` row isn't a
        /// bound Hub device — most likely a caregiver typed their Meridian
        /// Care login into the resident's phone.
        case notAuthorized
        case signedIn(profile: HubProfile)
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
            if session != nil {
                await resolveProfile()
            } else {
                state = .signedOut(error: nil)
            }
        }
    }

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            state = .signedOut(error: "Enter the email and password for this device.")
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await client.auth.signIn(email: email, password: password)
            await resolveProfile()
        } catch {
            state = .signedOut(error: "That email and password combination wasn't recognized.")
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        state = .signedOut(error: nil)
    }

    /// `public.resident_hub_profile` is row-level-security scoped to the
    /// signed-in device account, so it returns exactly one row for a bound Hub
    /// and zero rows for anybody else. Zero rows is the role gate, not an
    /// error — nothing here is worth alarming a resident about.
    private func resolveProfile() async {
        do {
            let profiles: [HubProfile] = try await client
                .from("resident_hub_profile")
                .select("facility_id,resident_id,room_id,display_name")
                .execute()
                .value

            if let profile = profiles.first {
                state = .signedIn(profile: profile)
            } else {
                state = .notAuthorized
            }
        } catch {
            state = .signedOut(error: "Couldn't reach Meridian just now. Try signing in again.")
        }
    }
}
