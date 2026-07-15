import SwiftUI

struct UpdatesView: View {
    @StateObject private var viewModel = UpdatesViewModel()

    private var incidentUpdates: [NotificationRow] {
        viewModel.notifications.filter { $0.incidentId != nil }
    }

    private var visitorAlerts: [NotificationRow] {
        viewModel.notifications.filter { $0.incidentId == nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notifications.isEmpty {
                    ContentUnavailableView(
                        "No updates yet",
                        systemImage: "bell",
                        description: Text("You'll see staff responses and visitor alerts here.")
                    )
                } else {
                    List {
                        if !incidentUpdates.isEmpty {
                            Section("Staff responses") {
                                ForEach(incidentUpdates) { notification in
                                    UpdateRow(notification: notification, isEmergency: true)
                                }
                            }
                        }
                        if !visitorAlerts.isEmpty {
                            Section("Visitors") {
                                ForEach(visitorAlerts) { notification in
                                    UpdateRow(notification: notification, isEmergency: false)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Updates")
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

private struct UpdateRow: View {
    let notification: NotificationRow
    let isEmergency: Bool

    var body: some View {
        HStack(alignment: .top, spacing: MeridianSpacing.sm) {
            Image(systemName: isEmergency ? "checkmark.shield.fill" : "door.left.hand.open")
                .foregroundStyle(isEmergency ? MeridianColor.success : MeridianColor.primary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.body)
                    .font(MeridianFont.body(15))
                    .foregroundStyle(MeridianColor.foreground)
                Text(notification.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(MeridianColor.foreground.opacity(0.5))
            }
        }
        .padding(.vertical, MeridianSpacing.unit)
        .alertArrival(isEmergency)
    }
}
