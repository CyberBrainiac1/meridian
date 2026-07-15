import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut(error: String?)
        /// Role gate: an account with no family_member_links row isn't a
        /// family account (e.g. facility staff who should use Meridian
        /// Care instead).
        case notAuthorized
        case signedIn(residents: [FamilyLinkedResident])
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
                await resolveLinkedResidents()
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
            try await client.auth.signIn(email: email, password: password)
            await resolveLinkedResidents()
        } catch {
            state = .signedOut(error: "That email and password combination wasn't recognized.")
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        state = .signedOut(error: nil)
    }

    private func resolveLinkedResidents() async {
        do {
            let residents: [FamilyLinkedResident] = try await client
                .from("family_linked_residents")
                .select()
                .execute()
                .value

            if residents.isEmpty {
                state = .notAuthorized
            } else {
                state = .signedIn(residents: residents)
            }
        } catch {
            state = .signedOut(error: "Couldn't load your account. Try signing in again.")
        }
    }
}
