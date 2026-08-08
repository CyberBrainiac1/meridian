import SwiftUI

struct RootView: View {
    let residents: [FamilyLinkedResident]

    var body: some View {
        TabView {
            DailySummaryView(residents: residents)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            UpdatesView()
                .tabItem { Label("Updates", systemImage: "bell.fill") }

            VisitorLogView()
                .tabItem { Label("Visitors", systemImage: "person.text.rectangle.fill") }

            PrivacyView(residents: residents)
                .tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
        .tint(MeridianColor.success)
    }
}
