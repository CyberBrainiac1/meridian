import SwiftUI

@main
struct MeridianHubApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.state {
                case .loading:
                    ProgressView()
                        .tint(MeridianColor.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(MeridianColor.background)
                case .signedOut(let error):
                    LoginView(errorMessage: error)
                case .notAuthorized:
                    NotAuthorizedView()
                case .signedIn(let profile):
                    RootView(profile: profile)
                }
            }
            .environmentObject(auth)
            .animation(.easeInOut(duration: MeridianMotion.duration), value: auth.state)
            .task { await auth.start() }
            // MeridianColor is a fixed light palette with no dark-mode
            // variants (Tokens.swift). Left to the system, Dark Mode swaps
            // default/unstyled text (e.g. TextField) to white, which is
            // invisible against these light, hardcoded backgrounds. Locking
            // the scheme keeps every default control legible against the
            // palette it was actually designed for. This exact bug shipped in
            // Care and Family before it was caught.
            .preferredColorScheme(.light)
        }
    }
}
