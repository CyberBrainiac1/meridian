import SwiftUI

/// One app, three interfaces.
///
/// Meridian used to ship as three separate binaries — MeridianCare,
/// MeridianHub and MeridianFamily — which meant a facility had to install and
/// keep track of the right one per device, and a free provisioning profile
/// could only hold three apps at all. They are now one target; who you are
/// decides what you see, which is also how the product actually thinks about
/// it: the same building, viewed from three positions.
@main
struct MeridianApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch auth.step {
                case .restoring:
                    RestoringView()
                case .choosingFacility:
                    FacilityPickerView()
                case .signingIn(let facility):
                    SignInView(facility: facility)
                case .notAuthorized:
                    NotAuthorizedView()
                case .ready(let surface):
                    surfaceView(for: surface)
                }
            }
            .environmentObject(auth)
            .animation(.easeInOut(duration: 0.2), value: auth.step)
            .task { await auth.start() }
            // Every palette in this app is a fixed light one with no dark
            // variants. Left to the system, Dark Mode turns unstyled text
            // white and it vanishes against these backgrounds — which is a
            // bug all three apps shipped with once already.
            .preferredColorScheme(.light)
        }
    }

    @ViewBuilder
    private func surfaceView(for surface: MeridianSurface) -> some View {
        switch surface {
        case .care(let facilityId, let facilityName, let role):
            CareRootView(facilityId: facilityId, facilityName: facilityName, role: role)
        case .hub(let profile):
            HubRootView(profile: profile)
        case .family(let residents):
            FamilyRootView(residents: residents)
        }
    }
}
