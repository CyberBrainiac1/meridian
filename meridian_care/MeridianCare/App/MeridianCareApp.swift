import SwiftUI

@main
struct MeridianCareApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(MeridianColor.background)
                case .signedOut(let error):
                    LoginView(errorMessage: error)
                case .notAuthorized:
                    NotAuthorizedView()
                case .signedIn(let facilityId, let facilityName, let role):
                    RootView(facilityId: facilityId, facilityName: facilityName, role: role)
                }
            }
            .environmentObject(auth)
            .animation(.easeInOut(duration: MeridianMotion.duration), value: auth.state)
            .task { await auth.start() }
        }
    }
}
