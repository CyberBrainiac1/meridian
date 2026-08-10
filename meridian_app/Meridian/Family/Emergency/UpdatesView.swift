import SwiftUI

struct UpdatesView: View {
    @StateObject private var viewModel = UpdatesViewModel()
    @State private var isShowingHelp = false

    private var incidentUpdates: [FamNotificationRow] {
        viewModel.notifications.filter { $0.incidentId != nil }
    }

    private var visitorAlerts: [FamNotificationRow] {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .frame(minWidth: FamTouchTarget.minSize, minHeight: FamTouchTarget.minSize)
                    }
                    .accessibilityLabel("Help")
                }
            }
            .sheet(isPresented: $isShowingHelp) {
                FamHelpTourView(topic: .updates)
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

private struct UpdateRow: View {
    let notification: FamNotificationRow
    let isEmergency: Bool

    var body: some View {
        HStack(alignment: .top, spacing: FamSpacing.sm) {
            Image(systemName: isEmergency ? "checkmark.shield.fill" : "person.text.rectangle.fill")
                .foregroundStyle(isEmergency ? FamColor.success : FamColor.primary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.body)
                    .font(FamFont.body(15))
                    .foregroundStyle(FamColor.foreground)
                Text(notification.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(FamColor.foregroundMuted)
            }
        }
        .padding(.vertical, FamSpacing.unit)
        .famAlertArrival(isEmergency)
    }
}
