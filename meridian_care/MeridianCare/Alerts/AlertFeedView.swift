import SwiftUI

struct AlertFeedView: View {
    @StateObject private var viewModel: AlertFeedViewModel
    @State private var quickActionError: String?

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
                                        Task {
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
                if let incident = viewModel.incidents.first(where: { $0.id == incidentId }) {
                    IncidentDetailView(incident: incident, copy: viewModel.copy(for: incident)) {
                        await viewModel.manualRefresh()
                    }
                }
            }
            .overlay(alignment: .top) {
                if let errorMessage = viewModel.errorMessage {
                    BannerText(text: errorMessage, tone: .warning)
                        .padding(.top, MeridianSpacing.xs)
                }
            }
            .alert("Couldn't update alert", isPresented: .constant(quickActionError != nil), actions: {
                Button("OK") { quickActionError = nil }
            }, message: {
                Text(quickActionError ?? "")
            })
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
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
