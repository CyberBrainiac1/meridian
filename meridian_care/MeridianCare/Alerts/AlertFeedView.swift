import SwiftUI

struct AlertFeedView: View {
    @StateObject private var viewModel: AlertFeedViewModel
    @State private var quickActionError: String?
    /// Guards the swipe action the same way IncidentDetailView guards its
    /// buttons — a double-swipe would otherwise fire two RPCs for one row.
    @State private var submittingIds: Set<String> = []
    @Environment(\.scenePhase) private var scenePhase

    init(facilityId: String) {
        _viewModel = StateObject(wrappedValue: AlertFeedViewModel(facilityId: facilityId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.incidents.isEmpty {
                    ContentUnavailableView(
                        "No active alerts",
                        systemImage: "checkmark.shield",
                        description: Text("Everyone's accounted for right now.")
                    )
                } else {
                    // Native SwiftUI List — built-in accessibility, scrolling,
                    // and swipe-action support, per the Care spec.
                    List {
                        ForEach(viewModel.incidents) { incident in
                            NavigationLink(value: incident.id) {
                                IncidentRow(incident: incident, copy: viewModel.copy(for: incident))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if incident.status.nextStatuses.contains(.acknowledged) {
                                    Button("Acknowledge") {
                                        guard !submittingIds.contains(incident.id) else { return }
                                        submittingIds.insert(incident.id)
                                        Task {
                                            defer { submittingIds.remove(incident.id) }
                                            let result = await IncidentActionService.respond(
                                                incidentId: incident.id,
                                                newStatus: .acknowledged
                                            )
                                            if case .failure(let error) = result {
                                                quickActionError = error.errorDescription
                                            } else {
                                                await viewModel.manualRefresh()
                                            }
                                        }
                                    }
                                    .tint(MeridianColor.primary)
                                    .disabled(submittingIds.contains(incident.id))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.manualRefresh() }
                }
            }
            .navigationTitle("Alerts")
            .navigationDestination(for: String.self) { incidentId in
                IncidentDetailHost(incidentId: incidentId, viewModel: viewModel)
            }
            .overlay(alignment: .top) {
                VStack(spacing: MeridianSpacing.unit) {
                    if !viewModel.isConnected {
                        BannerText(text: "Not connected — alerts may be delayed", tone: .warning)
                    }
                    if let errorMessage = viewModel.errorMessage {
                        BannerText(text: errorMessage, tone: .warning)
                    }
                }
                .padding(.top, MeridianSpacing.xs)
                .animation(.easeInOut(duration: MeridianMotion.duration), value: viewModel.isConnected)
            }
            .alert("Couldn't update alert", isPresented: .constant(quickActionError != nil), actions: {
                Button("OK") { quickActionError = nil }
            }, message: {
                Text(quickActionError ?? "")
            })
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, phase in
            // Tabs stay mounted and start()'s guard means the initial fetch
            // runs once per launch, so without this the feed comes back from
            // the background showing whatever it held when it left.
            guard phase == .active else { return }
            Task { await viewModel.manualRefresh() }
        }
    }
}

/// Owns its own copy of the incident instead of re-reading it from the feed
/// on every render. The feed carries only open/acknowledged/responding rows,
/// so the moment another caregiver resolves or escalates this one the row
/// disappears — and a lookup-based destination would blank the screen out
/// from under the caregiver, taking the explanation of what happened with it.
private struct IncidentDetailHost: View {
    let incidentId: String
    @ObservedObject var viewModel: AlertFeedViewModel

    @State private var incident: IncidentEvent?
    @State private var didRespondHere = false

    /// The row left the feed and it wasn't this caregiver's doing.
    private var claimedByAnother: Bool {
        incident != nil
            && !didRespondHere
            && !viewModel.incidents.contains(where: { $0.id == incidentId })
    }

    var body: some View {
        Group {
            if let incident {
                IncidentDetailView(incident: incident, copy: viewModel.copy(for: incident)) {
                    didRespondHere = true
                    await viewModel.manualRefresh()
                }
                .overlay(alignment: .top) {
                    if claimedByAnother {
                        BannerText(
                            text: "Another caregiver has already responded to this alert",
                            tone: .warning
                        )
                        .padding(.top, MeridianSpacing.xs)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Alert unavailable",
                    systemImage: "questionmark.circle",
                    description: Text("This alert is no longer in the feed.")
                )
            }
        }
        .onAppear { syncFromFeed() }
        .onChange(of: viewModel.incidents) { syncFromFeed() }
    }

    /// Deliberately one-way: it takes fresh status from the feed but never
    /// clears the local copy when the row drops out. Losing the incident is
    /// exactly the case this screen has to survive.
    private func syncFromFeed() {
        if let latest = viewModel.incidents.first(where: { $0.id == incidentId }) {
            incident = latest
        }
    }
}

struct BannerText: View {
    enum Tone { case warning, info }
    let text: String
    var tone: Tone = .info

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, MeridianSpacing.sm)
            .padding(.vertical, MeridianSpacing.xs)
            .background(
                (tone == .warning ? MeridianColor.warning : MeridianColor.primary).opacity(0.12),
                in: Capsule()
            )
            .foregroundStyle(tone == .warning ? MeridianColor.warning : MeridianColor.primary)
    }
}
