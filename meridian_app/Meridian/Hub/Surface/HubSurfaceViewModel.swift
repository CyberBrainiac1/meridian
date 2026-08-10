import Foundation
import Network
import Supabase

/// Ported from the retired web Hub's `components/hub-surface.tsx`.
///
/// Everything bounded, persistent or one-directional in here exists because of
/// a specific finding against the resident surface, not as general defensiveness:
/// a resident cannot be left watching a control that never resolves, cannot be
/// told something succeeded and then have it silently retracted, and cannot be
/// locked out of Emergency by some other slower action.

// MARK: - Notices

enum HubNoticeTone {
    case working, success, error
}

/// Confirmations and errors are persistent. Nothing here auto-dismisses: a
/// resident who looks up ten seconds late must still be able to read what
/// happened. The `id` makes each posting distinct so a repeat of the same
/// text still re-announces to VoiceOver.
struct HubNotice: Equatable, Identifiable {
    let id = UUID()
    let tone: HubNoticeTone
    let text: String
}

// MARK: - Busy

/// Which *single* control is in flight. Deliberately not a boolean: a slow
/// "Call family" must never be able to disable "Emergency help".
enum HubBusyKind: Equatable {
    case request(HubAssistanceKind)
    case visitor
}

// MARK: - Reminder rows

enum HubReminderKind {
    case medication, meal, walk
}

private extension HubActivityType {
    /// Only meal and walk activities have a reminder-row presentation today;
    /// `bathing`/`activity` have no icon or copy defined for this card yet,
    /// so they're left off rather than guessing at one.
    var reminderKind: HubReminderKind? {
        switch self {
        case .mealBreakfast, .mealLunch, .mealDinner: return .meal
        case .walk: return .walk
        case .bathing, .activity: return nil
        }
    }
}

struct HubReminderRow: Identifiable, Equatable {
    let id: String
    let kind: HubReminderKind
    let label: String
    let time: Date
    let done: Bool
    /// Every row here is backend-backed and one-directional: a self-report
    /// can't be un-tapped, whether it's a medication dose or a meal/walk
    /// activity. `locked` follows the same rule for both — true once the
    /// record is no longer outstanding.
    let locked: Bool
    let busy: Bool
    let dose: HubMedicationDose?
    let activity: HubActivity?
}

// MARK: - Action outcomes

enum HubActionOutcome: Equatable {
    case ok
    case failed(String)
    /// The round trip did not answer inside the bound. We do not know whether
    /// it landed, and we say exactly that rather than implying either.
    case timedOut
}

// MARK: - RPC parameter payloads

private struct CreateAssistanceParams: Encodable {
    let requestKind: String

    enum CodingKeys: String, CodingKey {
        case requestKind = "p_request_kind"
    }
}

private struct VisitorResponseParams: Encodable {
    let promptId: String
    let response: String

    enum CodingKeys: String, CodingKey {
        case promptId = "p_prompt_id"
        case response = "p_response"
    }
}

private struct MedicationReportParams: Encodable {
    let medicationId: String
    let scheduledFor: String

    enum CodingKeys: String, CodingKey {
        case medicationId = "p_medication_id"
        case scheduledFor = "p_scheduled_for"
    }
}

private struct ActivityReportParams: Encodable {
    let activityId: String
    let scheduledFor: String

    enum CodingKeys: String, CodingKey {
        case activityId = "p_activity_id"
        case scheduledFor = "p_scheduled_for"
    }
}

// MARK: - Write path

/// Mirrors the web app's `app/actions.ts`, including its error copy. Every
/// call is bounded: `timedOut` is a first-class outcome, never a spinner that
/// stays up forever.
enum HubActionService {
    static let timeout: TimeInterval = 15

    static func createAssistanceRequest(_ kind: HubAssistanceKind) async -> HubActionOutcome {
        await bounded {
            do {
                try await SupabaseManager.client
                    .rpc("create_resident_assistance_request",
                         params: CreateAssistanceParams(requestKind: kind.rawValue))
                    .execute()
                return .ok
            } catch {
                return .failed(
                    "Your request could not be sent. Please use the room call button or call care staff."
                )
            }
        }
    }

    static func answerVisitorPrompt(promptId: String, response: String) async -> HubActionOutcome {
        await bounded {
            do {
                try await SupabaseManager.client
                    .rpc("respond_to_visitor_verification",
                         params: VisitorResponseParams(promptId: promptId, response: response))
                    .execute()
                return .ok
            } catch {
                return .failed(
                    "We could not save your answer. Please use the room call button or call care staff."
                )
            }
        }
    }

    static func reportMedicationTaken(medicationId: String, scheduledFor: Date) async -> HubActionOutcome {
        await bounded {
            do {
                try await SupabaseManager.client
                    .rpc("resident_report_medication_taken",
                         params: MedicationReportParams(
                            medicationId: medicationId,
                            // Whole-minute dose slots, so the same plain ISO-8601
                            // encoding MeridianCare writes with is what the RPC's
                            // equality check against scheduled_for expects.
                            scheduledFor: ISO8601DateFormatter().string(from: scheduledFor)
                         ))
                    .execute()
                return .ok
            } catch {
                return .failed("We could not save that. Please tell a caregiver directly.")
            }
        }
    }

    static func reportActivityDone(activityId: String, scheduledFor: Date) async -> HubActionOutcome {
        await bounded {
            do {
                try await SupabaseManager.client
                    .rpc("resident_report_activity_done",
                         params: ActivityReportParams(
                            activityId: activityId,
                            // Same whole-minute, plain ISO-8601 encoding as the
                            // medication report — the RPC's equality check
                            // against scheduled_for expects it.
                            scheduledFor: ISO8601DateFormatter().string(from: scheduledFor)
                         ))
                    .execute()
                return .ok
            } catch {
                return .failed("We could not save that. Please tell a caregiver directly.")
            }
        }
    }

    /// Resolves to the action's outcome, or to `.timedOut` — never hangs.
    private static func bounded(
        _ work: @escaping @Sendable () async -> HubActionOutcome
    ) async -> HubActionOutcome {
        await withTaskGroup(of: HubActionOutcome.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
    }
}

// MARK: - Read path

enum HubFeedService {
    struct Snapshot {
        let requests: [HubAssistanceRequest]
        let prompts: [HubVisitorPrompt]
        let doses: [HubMedicationDose]
        let activities: [HubActivity]
    }

    static func load() async throws -> Snapshot {
        let client = SupabaseManager.client

        // Turns expired prompts into no_response *before* reading. Safe to call
        // repeatedly, and it is what stops a dead prompt staying actionable on
        // screen after its window closed.
        try await client.rpc("expire_my_visitor_verification_prompts").execute()

        async let requests: [HubAssistanceRequest] = client
            .from("resident_hub_assistance_feed")
            .select()
            .order("requested_at", ascending: false)
            .execute()
            .value

        async let prompts: [HubVisitorPrompt] = client
            .from("resident_hub_visitor_prompt_feed")
            .select()
            .order("prompted_at", ascending: false)
            .execute()
            .value

        async let doses: [HubMedicationDose] = client
            .from("resident_hub_medication_feed")
            .select()
            .order("scheduled_for", ascending: true)
            .execute()
            .value

        async let activities: [HubActivity] = client
            .from("resident_hub_activity_feed")
            .select()
            .order("scheduled_for", ascending: true)
            .execute()
            .value

        return Snapshot(
            requests: try await requests,
            prompts: try await prompts,
            doses: try await doses,
            activities: try await activities
        )
    }
}

// MARK: - Resident-facing copy

enum HubCopy {
    struct Eta {
        let title: String
        let note: String
    }

    /// An estimate is only ever shown with the reason it can be trusted — or
    /// the reason it cannot. `facilityDefault` names the conservative default
    /// plainly rather than referring to a figure that is not on screen.
    static func eta(for request: HubAssistanceRequest) -> Eta {
        let phrase = HubFormat.approxMinutes(request.etaSeconds)
        let title = "Someone should reach you in \(phrase)."
        switch request.etaConfidence {
        case .dataDerived:
            return Eta(title: title, note: "Based on how quickly staff answered recent calls here.")
        case .limitedHistory:
            return Eta(
                title: title,
                note: "This is an early estimate from only a few recent calls, so it may change."
            )
        case .facilityDefault:
            return Eta(
                title: title,
                note: "There is no response history for this building yet, so this is a cautious estimate rather than a measured time."
            )
        }
    }

    static func statusHeading(for request: HubAssistanceRequest) -> String {
        switch request.status {
        case .resolved:
            return "This help request is finished."
        case .cancelled:
            return "The care team cancelled this help request."
        case .enRoute:
            return "Help is coming. A caregiver is on the way."
        case .acknowledged:
            return "A caregiver has seen your request."
        case .open:
            if request.source == .autoFallDispatch {
                return "A fall was detected. Help was called for you."
            }
            return "Your request was sent to the care team."
        }
    }

    struct Step: Identifiable {
        let id: String
        let label: String
        let done: Bool
    }

    static func steps(for request: HubAssistanceRequest) -> [Step] {
        [
            Step(id: "sent", label: "Your request was sent", done: true),
            Step(id: "seen", label: "A caregiver has seen it", done: request.status != .open),
            Step(
                id: "on-the-way",
                label: "A caregiver is on the way",
                done: request.status == .enRoute || request.status == .resolved
            )
        ]
    }

    static let offlineRequest =
        "This screen is offline, so the request was not sent. Please press the call button by your bed, or call out for staff now."
    static let offlineAnswer =
        "This screen is offline, so your answer was not sent. Please press the call button by your bed, or call out for staff."
    static let requestTimedOut =
        "The request is taking too long to confirm, so we cannot be sure it was sent. Please press the call button by your bed, or call out for staff."
    static let answerTimedOut =
        "Your answer is taking too long to confirm. Please press the call button by your bed, or call out for staff."
    static let connectionProblem =
        "Connection problem: this screen cannot reach the care team right now. Please press the call button by your bed, or call out for staff."
}

// MARK: - View model

@MainActor
final class HubSurfaceViewModel: ObservableObject {
    static let pollInterval: TimeInterval = 10
    /// How long a finished request stays on screen so the resident actually
    /// reads the outcome instead of the panel silently reverting under them.
    static let terminalVisibleWindow: TimeInterval = 90

    @Published private(set) var assistanceRequests: [HubAssistanceRequest] = []
    @Published private(set) var visitorPrompts: [HubVisitorPrompt] = []
    @Published private(set) var medicationDoses: [HubMedicationDose] = []
    @Published private(set) var activities: [HubActivity] = []
    @Published private(set) var online = true
    @Published private(set) var busyKind: HubBusyKind?
    @Published private(set) var submittingDoseID: String?
    @Published private(set) var submittingActivityID: String?
    @Published private(set) var now = Date()
    @Published private(set) var notice: HubNotice?

    /// Never auto-opens. Help on this screen is something the resident reaches
    /// for, never something that interrupts them.
    @Published var isHelpOpen = false

    /// Same rule as `isHelpOpen`: never auto-opens. Messaging family is
    /// routine, not an interruption the resident should be pulled into.
    @Published var isMessagesOpen = false

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.meridianhub.app.network")
    /// The device's own reachability, kept separate from `online`. `online`
    /// also drops when a read fails against a reachable network; this one is
    /// what gates whether we even attempt a write.
    private var pathSatisfied = true
    private var pollTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var isRunning = false

    // MARK: Derived state

    var activeRequest: HubAssistanceRequest? {
        assistanceRequests.first { $0.status.isActive }
    }

    /// The most recent request that just finished, so "resolved" and
    /// "cancelled" are announced rather than causing the screen to change with
    /// no explanation.
    var recentlyFinishedRequest: HubAssistanceRequest? {
        assistanceRequests.first { request in
            guard !request.status.isActive, let endedAt = request.endedAt else { return false }
            return now.timeIntervalSince(endedAt) < Self.terminalVisibleWindow
        }
    }

    var shownRequest: HubAssistanceRequest? {
        activeRequest ?? recentlyFinishedRequest
    }

    var pendingPrompt: HubVisitorPrompt? {
        visitorPrompts.first { $0.status == .pending }
    }

    func secondsRemaining(for prompt: HubVisitorPrompt) -> Int {
        max(0, Int(prompt.expiresAt.timeIntervalSince(now).rounded()))
    }

    /// Medication rows and activity (meal/walk) rows, both from the feed.
    /// Only the current *local* calendar day — a resident reads "today" off a
    /// wall calendar, not a UTC boundary — and both feeds deliberately carry
    /// yesterday's slots too.
    var reminderRows: [HubReminderRow] {
        let calendar = Calendar.current

        let doseRows: [HubReminderRow] = medicationDoses
            .filter { dose in
                (dose.status == .outstanding || dose.status == .given)
                    && calendar.isDate(dose.scheduledFor, inSameDayAs: now)
            }
            .map { dose in
                HubReminderRow(
                    id: dose.id,
                    kind: .medication,
                    // Never names a drug, dose or instruction: the feed does not
                    // carry them, and this screen can face a shared room.
                    label: "Take your medication",
                    time: dose.scheduledFor,
                    done: dose.status != .outstanding,
                    locked: dose.status != .outstanding,
                    busy: submittingDoseID == dose.id,
                    dose: dose,
                    activity: nil
                )
            }

        let activityRows: [HubReminderRow] = activities
            .filter { activity in
                (activity.status == .outstanding || activity.status == .done)
                    && calendar.isDate(activity.scheduledFor, inSameDayAs: now)
            }
            .compactMap { activity -> HubReminderRow? in
                guard let kind = activity.activityType.reminderKind else { return nil }
                return HubReminderRow(
                    id: activity.id,
                    kind: kind,
                    label: activity.label,
                    time: activity.scheduledFor,
                    done: activity.status != .outstanding,
                    locked: activity.status != .outstanding,
                    busy: submittingActivityID == activity.id,
                    dose: nil,
                    activity: activity
                )
            }

        return (doseRows + activityRows).sorted { $0.time < $1.time }
    }

    var nextReminderID: String? {
        reminderRows.first { !$0.done }?.id
    }

    // MARK: Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.applyPath(satisfied: satisfied)
            }
        }
        monitor.start(queue: monitorQueue)

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                await self.pollIfIdle()
            }
        }

        // Drives the visitor countdown and the terminal-request window.
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                self.now = Date()
            }
        }

        Task { await refresh() }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        tickTask?.cancel()
        tickTask = nil
        monitor?.cancel()
        monitor = nil
        isRunning = false
    }

    private func applyPath(satisfied: Bool) {
        let wasOffline = !pathSatisfied
        pathSatisfied = satisfied
        if satisfied {
            if wasOffline {
                online = true
                Task { await refresh() }
            }
        } else {
            online = false
        }
    }

    /// Never re-render the panel out from under an in-flight tap.
    private func pollIfIdle() async {
        guard pathSatisfied, busyKind == nil, submittingDoseID == nil, submittingActivityID == nil else { return }
        await refresh()
    }

    func refresh() async {
        do {
            let snapshot = try await HubFeedService.load()
            assistanceRequests = snapshot.requests
            visitorPrompts = snapshot.prompts
            medicationDoses = snapshot.doses
            activities = snapshot.activities
            online = true
        } catch {
            // A failed background poll means we cannot show fresh status. It
            // must not retract a confirmation the resident has already been
            // given, so the notice is left untouched and only the connection
            // banner changes.
            online = false
        }
    }

    // MARK: Actions

    func submitRequest(_ kind: HubAssistanceKind) async {
        // Emergency must never be swallowed. Every other action yields to one
        // already in flight, but Emergency's button is deliberately never
        // disabled — so `guard busyKind == nil` used to drop the tap silently:
        // enabled button, no spinner, no notice, no request. A resident who
        // pressed "Call family" and then needed help within the next 15s got
        // nothing at all. Emergency now preempts instead.
        if kind == .emergency {
            guard busyKind != .request(.emergency) else { return }
        } else {
            guard busyKind == nil else { return }
        }

        guard pathSatisfied else {
            online = false
            notice = HubNotice(tone: .error, text: HubCopy.offlineRequest)
            return
        }

        // Feedback before the network is touched: the resident sees the tap land.
        busyKind = .request(kind)
        notice = HubNotice(tone: .working, text: "Sending your \(kind.label.lowercased()) request…")

        let outcome = await HubActionService.createAssistanceRequest(kind)

        // Only stand down if this is still the action the screen is showing.
        // A slower "Call family" finishing after an Emergency preempted it
        // must not clear Emergency's spinner or overwrite its message.
        let isStillCurrent = busyKind == .request(kind)
        if isStillCurrent {
            busyKind = nil
        }
        guard isStillCurrent || kind == .emergency else {
            // Superseded and not urgent: land the data, stay quiet.
            if case .ok = outcome { await refresh() }
            return
        }

        switch outcome {
        case .timedOut:
            notice = HubNotice(tone: .error, text: HubCopy.requestTimedOut)
        case .failed(let message):
            notice = HubNotice(tone: .error, text: message)
        case .ok:
            notice = HubNotice(
                tone: .success,
                text: kind == .familyContact
                    ? "Your family has been notified. They will be told you asked to speak with them."
                    : "Your request was sent. The care team has been notified."
            )
            await refresh()
        }
    }

    func respondToVisitor(_ prompt: HubVisitorPrompt, response: VisitorPromptStatus) async {
        guard response == .approved || response == .denied else { return }
        guard busyKind == nil else { return }
        guard pathSatisfied else {
            online = false
            notice = HubNotice(tone: .error, text: HubCopy.offlineAnswer)
            return
        }

        busyKind = .visitor
        notice = HubNotice(tone: .working, text: "Saving your answer…")

        let outcome = await HubActionService.answerVisitorPrompt(
            promptId: prompt.id,
            response: response.rawValue
        )
        busyKind = nil

        switch outcome {
        case .timedOut:
            notice = HubNotice(tone: .error, text: HubCopy.answerTimedOut)
        case .failed(let message):
            notice = HubNotice(tone: .error, text: message)
        case .ok:
            notice = HubNotice(
                tone: .success,
                text: response == .denied
                    ? "Thank you. The care team has been told to come and check."
                    : "Thank you. Your answer was saved."
            )
            await refresh()
        }
    }

    /// Self-report only — never a substitute for staff verification (see the
    /// migration comment on `resident_report_medication_taken`). One-directional
    /// by design: once reported, the row locks rather than offering an "undo"
    /// that would just silently no-op against an existing row anyway.
    func reportMedicationTaken(_ dose: HubMedicationDose) async {
        guard dose.status == .outstanding, submittingDoseID == nil else { return }
        let key = dose.id
        submittingDoseID = key
        // Optimistic: the tap should feel instant, not wait on a round trip.
        setDoseStatus(key, .given)

        let outcome = await HubActionService.reportMedicationTaken(
            medicationId: dose.medicationId,
            scheduledFor: dose.scheduledFor
        )
        submittingDoseID = nil

        switch outcome {
        case .ok:
            await refresh()
        case .timedOut:
            setDoseStatus(key, .outstanding)
            notice = HubNotice(
                tone: .error,
                text: "That didn't save in time. Please tell a caregiver directly."
            )
        case .failed(let message):
            setDoseStatus(key, .outstanding)
            notice = HubNotice(tone: .error, text: message)
        }
    }

    /// Self-report only, same guardrails as `reportMedicationTaken`: never a
    /// substitute for staff verification, and one-directional — once
    /// reported, the row locks rather than offering an "undo" that would
    /// just silently no-op against an existing row anyway.
    func reportActivityDone(_ activity: HubActivity) async {
        guard activity.status == .outstanding, submittingActivityID == nil else { return }
        let key = activity.id
        submittingActivityID = key
        // Optimistic: the tap should feel instant, not wait on a round trip.
        setActivityStatus(key, .done)

        let outcome = await HubActionService.reportActivityDone(
            activityId: activity.activityId,
            scheduledFor: activity.scheduledFor
        )
        submittingActivityID = nil

        switch outcome {
        case .ok:
            await refresh()
        case .timedOut:
            setActivityStatus(key, .outstanding)
            notice = HubNotice(
                tone: .error,
                text: "That didn't save in time. Please tell a caregiver directly."
            )
        case .failed(let message):
            setActivityStatus(key, .outstanding)
            notice = HubNotice(tone: .error, text: message)
        }
    }

    func toggle(_ row: HubReminderRow) async {
        switch row.kind {
        case .medication:
            guard let dose = row.dose else { return }
            await reportMedicationTaken(dose)
        case .meal, .walk:
            guard let activity = row.activity else { return }
            await reportActivityDone(activity)
        }
    }

    private func setDoseStatus(_ id: String, _ status: HubMedicationDoseStatus) {
        medicationDoses = medicationDoses.map { dose in
            guard dose.id == id else { return dose }
            return HubMedicationDose(
                medicationId: dose.medicationId,
                scheduledFor: dose.scheduledFor,
                status: status
            )
        }
    }

    private func setActivityStatus(_ id: String, _ status: HubActivityCompletionStatus) {
        activities = activities.map { activity in
            guard activity.id == id else { return activity }
            return HubActivity(
                activityId: activity.activityId,
                activityType: activity.activityType,
                label: activity.label,
                scheduledFor: activity.scheduledFor,
                status: status
            )
        }
    }
}
