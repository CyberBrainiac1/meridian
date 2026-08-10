import Foundation
import Network
import Supabase

/// Mirrors `HubSurfaceViewModel`'s guardrails for the resident<->family chat
/// thread: bounded writes (never a spinner that hangs forever), a persistent
/// notice for anything that fails, and a message the resident sent that
/// appears immediately rather than waiting on a round trip.
///
/// There is no realtime-channel precedent anywhere else in this app —
/// `HubSurfaceViewModel` reads `resident_hub_*` on a plain poll timer, not a
/// Postgres Changes subscription — so this view model follows that same
/// pattern rather than introducing a new one: a short poll while the thread
/// is open, plus an immediate refresh right after a send.

// MARK: - Insert payload

/// The Hub supplies only what it legitimately knows — which thread, and what
/// to say. `sender_role`, `sender_user_id` and `facility_id` are all derived
/// server-side from the caller's identity by `send_message`.
private struct SendMessageParams: Encodable {
    let residentId: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case residentId = "p_resident_id"
        case body = "p_body"
    }
}

// MARK: - Write / read path

enum MessageService {
    /// RLS already scopes `messages` to this Hub's own resident thread (see
    /// `Domain/Types.swift`), so — same as `HubFeedService.load()` reading
    /// the other `resident_hub_*` feeds — this deliberately does not add its
    /// own `resident_id` filter on top of that.
    static func load(residentId: String) async throws -> [Message] {
        try await SupabaseManager.client
            .from("messages")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Goes through the `send_message` RPC rather than inserting directly.
    /// A direct insert has to supply `facility_id` (NOT NULL, and matched on
    /// by the insert RLS policy) plus `sender_role`/`sender_user_id`, and
    /// omitting the facility silently failed every send — the RPC derives all
    /// three from the caller's own identity, so this client cannot get them
    /// wrong or assert a role that isn't its own.
    static func send(residentId: String, body: String) async -> HubActionOutcome {
        await bounded {
            do {
                try await SupabaseManager.client
                    .rpc(
                        "send_message",
                        params: SendMessageParams(residentId: residentId, body: body)
                    )
                    .execute()
                return .ok
            } catch {
                return .failed(
                    "Your message could not be sent. Please use the room call button or call care staff if this is urgent."
                )
            }
        }
    }

    /// Same bound as `HubActionService`'s writes (`HubActionService.timeout`,
    /// 15s) — never a spinner that hangs forever, and the resident is told
    /// plainly when we can no longer promise the message landed.
    /// `HubActionService.bounded` itself is private to that enum, so this is
    /// the same race-with-a-timer shape reusing the same timeout constant,
    /// not a new one.
    private static func bounded(
        _ work: @escaping @Sendable () async -> HubActionOutcome
    ) async -> HubActionOutcome {
        await withTaskGroup(of: HubActionOutcome.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(HubActionService.timeout * 1_000_000_000))
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
    }
}

// MARK: - View model

@MainActor
final class MessageThreadViewModel: ObservableObject {
    /// No realtime-channel precedent exists anywhere in this app (see file
    /// comment), so new messages arrive the same way the rest of the Hub's
    /// data does: a short poll while the sheet is open. 6s keeps a reply from
    /// a family member feeling close to live without hammering the network.
    static let pollInterval: TimeInterval = 6

    let profile: HubProfile

    @Published private(set) var messages: [Message] = []
    @Published var draft: String = ""
    @Published private(set) var isLoading = true
    @Published private(set) var isSending = false
    @Published private(set) var online = true
    @Published private(set) var notice: HubNotice?
    /// Optimistic entries not yet confirmed by the server, so a bubble can
    /// say "Sending…" instead of quietly implying it already arrived.
    @Published private(set) var pendingIDs: Set<String> = []

    private var currentUserId: String?
    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.meridianhub.app.messages.network")
    /// Same split as `HubSurfaceViewModel`: `pathSatisfied` is the device's
    /// own reachability and is what gates a write; `online` also reflects a
    /// failed read and only affects what's shown.
    private var pathSatisfied = true
    private var pollTask: Task<Void, Never>?
    private var isRunning = false

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    init(profile: HubProfile) {
        self.profile = profile
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

        Task {
            await resolveCurrentUser()
            await refresh()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
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

    /// Never re-render the thread out from under an in-flight send.
    private func pollIfIdle() async {
        guard pathSatisfied, !isSending else { return }
        await refresh()
    }

    private func resolveCurrentUser() async {
        guard currentUserId == nil else { return }
        currentUserId = try? await SupabaseManager.client.auth.session.user.id.uuidString
    }

    func refresh() async {
        do {
            let loaded = try await MessageService.load(residentId: profile.residentId)
            // A poll landing mid-send must never erase the bubble the
            // resident is watching — only replace the list once nothing from
            // this device is still pending confirmation.
            if pendingIDs.isEmpty {
                messages = loaded
            } else {
                let pending = messages.filter { pendingIDs.contains($0.id) }
                messages = loaded + pending
            }
            online = true
            isLoading = false
        } catch {
            // A failed background poll must not retract messages already on
            // screen — only the connection banner changes.
            online = false
            isLoading = false
        }
    }

    // MARK: Sending

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        guard pathSatisfied else {
            online = false
            notice = HubNotice(tone: .error, text: Self.offlineSendCopy)
            return
        }

        if currentUserId == nil {
            await resolveCurrentUser()
        }
        guard let senderUserId = currentUserId else {
            notice = HubNotice(
                tone: .error,
                text: "We could not verify who you're signed in as, so this message was not sent. Please tell a caregiver directly."
            )
            return
        }

        // 1-2000 chars per the `messages` table constraint.
        let trimmedBody = String(text.prefix(2000))
        let tempID = "pending-\(UUID().uuidString)"
        let optimistic = Message(
            id: tempID,
            residentId: profile.residentId,
            senderRole: .resident,
            senderUserId: senderUserId,
            senderName: profile.displayName,
            body: trimmedBody,
            createdAt: Date()
        )

        // Feedback before the network is touched: the resident sees the tap
        // land immediately, same as every other action on this Hub.
        isSending = true
        pendingIDs.insert(tempID)
        messages.append(optimistic)
        draft = ""

        let outcome = await MessageService.send(
            residentId: profile.residentId,
            body: trimmedBody
        )
        isSending = false
        pendingIDs.remove(tempID)

        switch outcome {
        case .ok:
            // Replaces the optimistic bubble with the real row from the
            // server, same "read is the source of truth" rule as everywhere
            // else on this Hub.
            await refresh()
        case .timedOut:
            messages.removeAll { $0.id == tempID }
            draft = trimmedBody
            notice = HubNotice(
                tone: .error,
                text: "Your message is taking too long to confirm, so we cannot be sure it was sent. Please try again, or use the room call button or call care staff if this is urgent."
            )
        case .failed(let message):
            messages.removeAll { $0.id == tempID }
            draft = trimmedBody
            notice = HubNotice(tone: .error, text: message)
        }
    }

    /// Matches the wording pattern of `HubCopy.offlineRequest` /
    /// `HubCopy.offlineAnswer` in `HubSurfaceViewModel.swift`, with "message"
    /// substituted for "request"/"answer".
    private static let offlineSendCopy =
        "This screen is offline, so your message was not sent. Please press the call button by your bed, or call out for staff if you need something now."
}
