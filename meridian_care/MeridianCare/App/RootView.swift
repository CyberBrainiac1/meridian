import SwiftUI

struct RootView: View {
    let facilityId: String
    let facilityName: String
    let role: FacilityRole
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var visitorBanner: VisitorBannerViewModel

    init(facilityId: String, facilityName: String, role: FacilityRole) {
        self.facilityId = facilityId
        self.facilityName = facilityName
        self.role = role
        _visitorBanner = StateObject(wrappedValue: VisitorBannerViewModel(facilityId: facilityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            VisitorBannerView(viewModel: visitorBanner)
                .animation(.easeInOut(duration: MeridianMotion.duration), value: visitorBanner.isVisible)

            TabView {
                AlertFeedView(facilityId: facilityId)
                    .tabItem { Label("Alerts", systemImage: "bell.badge") }

                ShiftHandoffView(facilityId: facilityId)
                    .tabItem { Label("Handoff", systemImage: "list.clipboard") }

                ResidentProfilesView(facilityId: facilityId)
                    .tabItem { Label("Residents", systemImage: "person.2") }

                SettingsView(facilityName: facilityName, role: role)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .tint(MeridianColor.primary)
        }
        .task { visitorBanner.start() }
        .onDisappear { visitorBanner.stop() }
    }
}

struct SettingsView: View {
    let facilityName: String
    let role: FacilityRole
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Facility") {
                    LabeledContent("Name", value: facilityName)
                    LabeledContent("Your role", value: role.rawValue.capitalized)
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                    .frame(minHeight: MeridianTouchTarget.minSize)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
