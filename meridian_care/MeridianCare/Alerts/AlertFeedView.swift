import SwiftUI

struct AlertFeedView: View {
    /// Owned by RootView (shared with the urgent-alert overlay), not this
    /// view — an incident acknowledged from the full-screen interrupt has to
    /// disappear from this list without a second fetch.
    @ObservedObject var viewModel: AlertFeedViewModel
    /// Also owned by RootView, and deliberately the *same* instance the
    /// urgent-assistance overlay reads: acknowledging from the full-screen
    /// interrupt has to move the row in this list, and vice versa.
    @ObservedObject var assistanceViewModel: AssistanceRequestViewModel
    /// Set by RootView's "View alert" action to jump straight into an
    /// incident's detail screen, bypassing the list.
    @Binding var pendingOpenIncidentId: String?
    @State private var path: [String] = []
    @State private var quickActionError: String?
    /// Guards the swipe action the same way IncidentDetailView guards its
    /// buttons — a double-swipe would otherwise fire two RPCs for one row.
    @State private var submittingIds: Set<String> = []
    /// Same guard for the assistance rows' buttons — two taps on "Resolve"
    /// would otherwise fire two RPCs, the second failing as an invalid
    /// transition and showing the caregiver an error for work that succeeded.
    @State private var submittingAssistanceIds: Set<String> = []
    @State private var assistanceActionError: String?
    @Environment(\.scenePhase) private var scenePhase

    /// Resident-initiated (or auto-dispatched) calls for help, emergencies
    /// first and newest first within each group. The feed query already
    /// restricts to active statuses; filtering again here keeps the section
    /// honest if a row is mutated in place between refreshes.
    private var activeRequests: [AssistanceRequest] {
        assistanceViewModel.requests
            .filter { $0.status.isActive }
            .sorted { lhs, rhs in
                let lhsUrgent = lhs.requestKind == .emergency
                let rhsUrgent = rhs.requestKind == .emergency
                if lhsUrgent != rhsUrgent { return lhsUrgent }
                return lhs.requestedAt > rhs.requestedAt
            }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.incidents.isEmpty && activeRequests.isEmpty {
                    ContentUnavailableView(
                        "No active alerts",
                        systemImage: "checkmark.shield",
                        description: Text("Everyone's accounted for right now.")
                    )
                } else {
                    // Native SwiftUI List — built-in accessibility, scrolling,
                    // and swipe-action support, per the Care spec.
                    List {
                        // Headers appear only once there's more than one kind
                        // of thing in the list: with no resident requests the
                        // feed stays exactly the flat list it has always been.
                        if activeRequests.isEmpty {
                            incidentRows
                        } else {
                            Section("Resident requests") {
                                ForEach(activeRequests) { request in
                                    assistanceRow(for: request)
                                }
                            }
                            Section("Detected alerts") {
                                if viewModel.incidents.isEmpty {
                                    Text("No active alerts — everyone's accounted for right now.")
                                        .font(MeridianFont.body(15))
                                        .foregroundStyle(MeridianColor.foregroundMuted)
                                        .padding(.vertical, MeridianSpacing.xs)
                                } else {
                                    incidentRows
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.manualRefresh()
                        await assistanceViewModel.manualRefresh()
                    }
                }
            }
            .navigationTitle("Alerts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HelpToolbarButton(topic: .alerts)
                }
            }
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
                    if let assistanceError = assistanceViewModel.errorMessage {
                        BannerText(text: assistanceError, tone: .warning)
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
        .onChange(of: pendingOpenIncidentId) { _, newValue in
            guard let newValue else { return }
            path = [newValue]
            pendingOpenIncidentId = nil
        }
        .onChange(of: scenePhase) { _, phase in
            // Tabs stay mounted and start()'s guard means the initial fetch
            // runs once per launch, so without this the feed comes back from
            // the background showing whatever it held when it left.
            guard phase == .active else { return }
            Task { await viewModel.manualRefresh() }
            Task { await assistanceViewModel.manualRefresh() }
        }
        // Attached to the NavigationStack rather than to the Group the
        // incident alert uses: two alert modifiers on the same view fight
        // over presentation, on separate views they don't.
        .alert("Couldn't update request", isPresented: .constant(assistanceActionError != nil), actions: {
            Button("OK") { assistanceActionError = nil }
        }, message: {
            Text(assistanceActionError ?? "")
        })
    }

    /// Extracted verbatim from the previous inline body so the same rows can
    /// be rendered either bare or inside a labelled section. Incident
    /// behavior is unchanged.
    @ViewBuilder
    private var incidentRows: some View {
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

    private func assistanceRow(for request: AssistanceRequest) -> some View {
        AssistanceRequestRow(
            request: request,
            residentName: assistanceViewModel.residentName(for: request),
            room: assistanceViewModel.residents[request.residentId]?.roomId ?? request.roomId,
            isSubmitting: submittingAssistanceIds.contains(request.id),
            onRespond: { newStatus in respond(to: request, newStatus: newStatus) }
        )
    }

    private func respond(to request: AssistanceRequest, newStatus: AssistanceStatus) {
        guard !submittingAssistanceIds.contains(request.id) else { return }
        submittingAssistanceIds.insert(request.id)
        Task {
            defer { submittingAssistanceIds.remove(request.id) }
            let result = await AssistanceActionService.respond(
                assistanceRequestId: request.id,
                newStatus: newStatus
            )
            if case .failure(let error) = result {
                assistanceActionError = error.errorDescription
            } else {
                await assistanceViewModel.manualRefresh()
            }
        }
    }
}

/// One resident-initiated call for help. Same row anatomy as IncidentRow
/// (badge + relative time, then the resident-first sentence, then status),
/// with the response buttons inline because there is no detail screen behind
/// this row to hold them.
private struct AssistanceRequestRow: View {
    let request: AssistanceRequest
    let residentName: String
    let room: String
    let isSubmitting: Bool
    let onRespond: (AssistanceStatus) -> Void

    /// Mirrors IncidentStatus.nextStatuses: only offer transitions
    /// respond_to_assistance_request will actually accept.
    private var offeredStatuses: [AssistanceStatus] {
        switch request.status {
        case .open: return [.acknowledged]
        case .acknowledged: return [.enRoute, .resolved]
        case .enRoute: return [.resolved]
        case .resolved, .cancelled: return []
        }
    }

    private var summary: String {
        switch request.requestKind {
        case .emergency: return "\(residentName) needs emergency help in \(room)"
        case .familyContact: return "\(residentName) is requesting a family call in \(room)"
        case .assistance: return "\(residentName) needs help in \(room)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.unit * 1.5) {
            HStack {
                AssistanceKindBadge(kind: request.requestKind)
                Spacer()
                Text(MeridianFormat.relativeTime(request.requestedAt))
                    .font(.footnote)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }
            Text(summary)
                .font(MeridianFont.bodyMedium(17))
                .foregroundStyle(MeridianColor.foreground)
            Text(request.status.careLabel)
                .font(.footnote)
                .foregroundStyle(MeridianColor.foregroundMuted)
                .accessibilityLabel("Status: \(request.status.careLabel)")

            if !offeredStatuses.isEmpty {
                HStack(spacing: MeridianTouchTarget.minSpacing) {
                    ForEach(offeredStatuses, id: \.rawValue) { status in
                        Button(status.actionTitle) { onRespond(status) }
                            .buttonStyle(MeridianButtonStyle(kind: status == .resolved ? .success : .primary))
                            .disabled(isSubmitting)
                            .accessibilityLabel("\(status.actionTitle), \(residentName), \(room)")
                    }
                }
                .padding(.top, MeridianSpacing.unit)
            }
        }
        .padding(.vertical, MeridianSpacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(request.requestKind.label). \(summary). \(request.status.careLabel). \(MeridianFormat.relativeTime(request.requestedAt))")
    }
}

/// SeverityBadge's counterpart for assistance requests — same anatomy (icon +
/// word + 12% tint), and the same rule that the word, never the colour, is
/// what carries the meaning.
private struct AssistanceKindBadge: View {
    let kind: AssistanceKind

    private var tintColor: Color {
        switch kind {
        case .emergency: return MeridianColor.destructive
        case .assistance: return MeridianColor.warning
        case .familyContact: return MeridianColor.primary
        }
    }

    private var textColor: Color {
        switch kind {
        case .emergency: return MeridianColor.destructiveStrong
        case .assistance: return MeridianColor.warningStrong
        case .familyContact: return MeridianColor.primary
        }
    }

    private var systemImage: String {
        switch kind {
        case .emergency: return "exclamationmark.octagon.fill"
        case .assistance: return "hand.raised.fill"
        case .familyContact: return "phone.fill"
        }
    }

    var body: some View {
        Label(kind.label, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tintColor.opacity(0.12), in: Capsule())
            .accessibilityLabel(kind.label)
    }
}

/// Care-facing wording for AssistanceStatus. Kept here rather than on the
/// model in Domain/Types.swift, which is a straight mirror of the SQL schema
/// and stays free of app copy.
private extension AssistanceStatus {
    var careLabel: String {
        switch self {
        case .open: return "Waiting for a caregiver"
        case .acknowledged: return "Acknowledged"
        case .enRoute: return "Caregiver on the way"
        case .resolved: return "Resolved"
        case .cancelled: return "Cancelled"
        }
    }

    /// Button wording for a transition *into* this status.
    var actionTitle: String {
        switch self {
        case .acknowledged: return "Acknowledge"
        case .enRoute: return "On my way"
        case .resolved: return "Resolve"
        case .open: return "Reopen"
        case .cancelled: return "Cancel"
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
