import SwiftUI

struct RootView: View {
    let facilityId: String
    let facilityName: String
    let role: FacilityRole
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var visitorBanner: VisitorBannerViewModel
    @StateObject private var alertFeed: AlertFeedViewModel
    @StateObject private var medicationWatcher: MedicationWatcher
    @StateObject private var activityWatcher: ActivityWatcher
    @StateObject private var assistanceFeed: AssistanceRequestViewModel
    @State private var dismissedUrgentIds: Set<String> = []
    @State private var dismissedUrgentAssistanceIds: Set<String> = []
    @State private var pendingOpenIncidentId: String?
    @State private var selectedTab: Tab = .alerts

    enum Tab { case alerts, handoff, residents, settings }

    init(facilityId: String, facilityName: String, role: FacilityRole) {
        self.facilityId = facilityId
        self.facilityName = facilityName
        self.role = role
        _visitorBanner = StateObject(wrappedValue: VisitorBannerViewModel(facilityId: facilityId))
        _alertFeed = StateObject(wrappedValue: AlertFeedViewModel(facilityId: facilityId))
        _medicationWatcher = StateObject(wrappedValue: MedicationWatcher(facilityId: facilityId))
        _activityWatcher = StateObject(wrappedValue: ActivityWatcher(facilityId: facilityId))
        _assistanceFeed = StateObject(wrappedValue: AssistanceRequestViewModel(facilityId: facilityId))
    }

    /// The first open, non-info incident not yet dismissed from the urgent
    /// overlay this session. Only ever one at a time, mirroring the design —
    /// stacking full-screen interrupts is its own hazard.
    private var urgentIncident: IncidentEvent? {
        alertFeed.incidents.first {
            $0.status == .open && $0.severity != .info && !dismissedUrgentIds.contains($0.id)
        }
    }

    /// The first open, `.emergency`-kind assistance request not yet
    /// dismissed this session — mirrors `urgentIncident`'s shape. A resident
    /// pressing Emergency on the Hub is a second source of "full-screen
    /// interrupt worthy" urgency alongside a detected incident.
    private var urgentAssistanceRequest: AssistanceRequest? {
        assistanceFeed.requests.first {
            $0.status == .open && $0.requestKind == .emergency && !dismissedUrgentAssistanceIds.contains($0.id)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VisitorBannerView(viewModel: visitorBanner)
                    .animation(.easeInOut(duration: MeridianMotion.duration), value: visitorBanner.isVisible)

                TabView(selection: $selectedTab) {
                    AlertFeedView(
                        viewModel: alertFeed,
                        assistanceViewModel: assistanceFeed,
                        pendingOpenIncidentId: $pendingOpenIncidentId
                    )
                        .tabItem { Label("Alerts", systemImage: "bell.badge") }
                        .tag(Tab.alerts)

                    ShiftHandoffView(facilityId: facilityId)
                        .tabItem { Label("Handoff", systemImage: "list.clipboard") }
                        .tag(Tab.handoff)

                    ResidentProfilesView(facilityId: facilityId)
                        .tabItem { Label("Residents", systemImage: "person.2") }
                        .tag(Tab.residents)

                    SettingsView(facilityName: facilityName, role: role)
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(Tab.settings)
                }
                .tint(MeridianColor.primary)
            }

            if let urgentIncident {
                UrgentAlertOverlay(
                    incident: urgentIncident,
                    copy: alertFeed.copy(for: urgentIncident),
                    onAcknowledge: {
                        dismissedUrgentIds.insert(urgentIncident.id)
                        Task {
                            _ = await IncidentActionService.respond(incidentId: urgentIncident.id, newStatus: .acknowledged)
                            await alertFeed.manualRefresh()
                        }
                    },
                    onView: {
                        dismissedUrgentIds.insert(urgentIncident.id)
                        selectedTab = .alerts
                        pendingOpenIncidentId = urgentIncident.id
                    },
                    onClose: {
                        dismissedUrgentIds.insert(urgentIncident.id)
                    }
                )
                .transition(.opacity)
            } else if let urgentAssistanceRequest {
                // Incident takes priority if both are somehow true at once —
                // simplest deterministic tie-break, one urgent full-screen
                // interrupt on screen at a time per the principle above.
                UrgentAssistanceOverlay(
                    request: urgentAssistanceRequest,
                    residentName: assistanceFeed.residentName(for: urgentAssistanceRequest),
                    onAcknowledge: {
                        dismissedUrgentAssistanceIds.insert(urgentAssistanceRequest.id)
                        Task {
                            _ = await AssistanceActionService.respond(
                                assistanceRequestId: urgentAssistanceRequest.id,
                                newStatus: .acknowledged
                            )
                            await assistanceFeed.manualRefresh()
                        }
                    },
                    onView: {
                        // Dismissing the full-screen interrupt is safe now
                        // that the request has a real surface: the Alerts
                        // tab's "Resident requests" section renders it (and
                        // its Acknowledge/On my way/Resolve actions) from the
                        // same feed this overlay reads.
                        // `dismissedUrgentAssistanceIds` gates only this
                        // overlay — never the list row.
                        dismissedUrgentAssistanceIds.insert(urgentAssistanceRequest.id)
                        selectedTab = .alerts
                    },
                    onClose: {
                        dismissedUrgentAssistanceIds.insert(urgentAssistanceRequest.id)
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: MeridianMotion.duration), value: urgentIncident?.id)
        .animation(.easeInOut(duration: MeridianMotion.duration), value: urgentAssistanceRequest?.id)
        .task {
            AlertNotificationService.shared.onOpenIncident = { incidentId in
                selectedTab = .alerts
                pendingOpenIncidentId = incidentId
            }
            AlertNotificationService.shared.onOpenAssistanceRequest = { _ in
                // Same landing spot as the overlay's "View" above, and now a
                // real one: every active request — emergency or routine —
                // is listed in the Alerts tab's "Resident requests" section.
                selectedTab = .alerts
            }
            AlertNotificationService.shared.requestAuthorizationAndRegisterCategory()
            visitorBanner.start()
            alertFeed.start()
            medicationWatcher.start()
            activityWatcher.start()
            assistanceFeed.start()
        }
        .onDisappear {
            visitorBanner.stop()
            alertFeed.stop()
            medicationWatcher.stop()
            activityWatcher.stop()
            assistanceFeed.stop()
        }
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
