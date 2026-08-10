import Foundation
import Supabase

enum MessagingError: Error {
    case timedOut
}

/// Insert payload for public.messages. A separate type from `Message`
/// because the row's `id`/`created_at` are server-generated — the client
/// never supplies them.
private struct SendMessageParams: Encodable {
    let residentId: String
    let body: String
    let senderName: String?

    enum CodingKeys: String, CodingKey {
        case residentId = "p_resident_id"
        case body = "p_body"
        case senderName = "p_sender_name"
    }
}

/// One shared thread per resident (see Message's doc comment in Types.swift)
/// — the picker (when there's more than one linked resident) just changes
/// which resident's thread is loaded, it never creates a 1:1 sub-thread.
@MainActor
final class MessagesViewModel: ObservableObject {
    let residents: [FamilyLinkedResident]

    @Published var selectedResidentId: String
    @Published private(set) var messages: [Message] = []
    @Published var draftText = ""
    @Published private(set) var isSending = false
    @Published var loadErrorMessage: String?
    @Published var sendErrorMessage: String?

    /// Nothing in this app currently carries the signed-in family member's
    /// own display name (AuthViewModel only has email/password;
    /// FamilyLinkedResident is the *resident's* name). We first check the
    /// Supabase auth user's metadata in case it was ever set at signup,
    /// then fall back to asking once and caching the answer locally.
    @Published var isPromptingForName = false
    @Published var pendingName = ""

    private var pollTask: Task<Void, Never>?
    private var currentUserId: String?
    private var currentUserName: String?
    private let sendTimeoutSeconds: Double = 15

    var selectedResident: FamilyLinkedResident? {
        residents.first { $0.residentId == selectedResidentId }
    }

    init(residents: [FamilyLinkedResident]) {
        self.residents = residents
        self.selectedResidentId = residents.first?.residentId ?? ""
    }

    func isOwnMessage(_ message: Message) -> Bool {
        message.senderRole == .family && message.senderUserId == currentUserId
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task {
            await resolveSender()
            while !Task.isCancelled {
                await loadMessages()
                // No realtime-channel pattern exists anywhere in this app —
                // DailySummary/Updates/VisitorLog view models all poll
                // (20s/15s/20s). `messages` mirrors that instead of
                // introducing a new pattern, at a shorter 6s interval since
                // a live conversation is more time-sensitive than a daily
                // rollup. The table is in the realtime publication
                // server-side, so a genuine Postgres Changes subscription
                // is a reasonable follow-up, not attempted here.
                try? await Task.sleep(for: .seconds(6))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func selectResident(_ residentId: String) {
        guard residentId != selectedResidentId else { return }
        selectedResidentId = residentId
        messages = []
        loadErrorMessage = nil
        sendErrorMessage = nil
        Task { await loadMessages() }
    }

    private func resolveSender() async {
        do {
            let session = try await SupabaseManager.client.auth.session
            let userId = session.user.id.uuidString
            currentUserId = userId

            if let metadataName = session.user.userMetadata["full_name"]?.stringValue
                ?? session.user.userMetadata["name"]?.stringValue,
                !metadataName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentUserName = metadataName
                return
            }

            if let cachedName = UserDefaults.standard.string(forKey: Self.nameCacheKey(for: userId)),
                !cachedName.isEmpty {
                currentUserName = cachedName
                return
            }

            isPromptingForName = true
        } catch {
            loadErrorMessage = "Couldn't verify your account. Try again."
        }
    }

    func confirmPendingName() {
        let trimmed = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentUserName = trimmed
        // Persist only if we know who to file it under. Previously the whole
        // confirm was gated on having a user id, so if the session lookup had
        // failed, tapping Continue did nothing at all — and with
        // `.interactiveDismissDisabled()` and no cancel, that left the app
        // stuck on an undismissable sheet. The name is useful in memory
        // regardless: `send_message` derives identity from auth.uid()
        // server-side and never needs the client's copy.
        if let userId = currentUserId {
            UserDefaults.standard.set(trimmed, forKey: Self.nameCacheKey(for: userId))
        }
        isPromptingForName = false
        pendingName = ""
    }

    /// Lets the resident back out of the name sheet. Without this the sheet
    /// is a dead end whenever the name can't be confirmed.
    func cancelNamePrompt() {
        isPromptingForName = false
        pendingName = ""
    }

    func loadMessages() async {
        guard !selectedResidentId.isEmpty else { return }
        do {
            let rows: [Message] = try await SupabaseManager.client
                .from("messages")
                .select()
                .eq("resident_id", value: selectedResidentId)
                .order("created_at", ascending: true)
                .execute()
                .value
            messages = rows
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load messages."
        }
    }

    func send() async {
        let body = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !selectedResidentId.isEmpty else { return }
        // Only the display name is needed here. `send_message` resolves the
        // facility, the sender role and the sender's id from auth.uid() on the
        // server, so a failed client-side session lookup must not block a
        // send that would otherwise succeed.
        guard let name = currentUserName else {
            isPromptingForName = true
            return
        }

        isSending = true
        sendErrorMessage = nil
        defer { isSending = false }

        // Goes through the `send_message` RPC rather than inserting directly.
        // A direct insert must supply `facility_id` (NOT NULL, and matched on
        // by the insert RLS policy), which this app has no natural source for
        // — omitting it silently failed every send and surfaced as a
        // misleading "check your connection". The RPC derives facility,
        // sender role and sender id from the caller's own identity.
        let params = SendMessageParams(
            residentId: selectedResidentId,
            body: body,
            senderName: name
        )

        do {
            try await withTimeout(seconds: sendTimeoutSeconds) {
                _ = try await SupabaseManager.client
                    .rpc("send_message", params: params)
                    .execute()
            }
            draftText = ""
            await loadMessages()
        } catch {
            // Persistent, non-auto-dismissing — cleared only on the next
            // send attempt (above), matching how loadErrorMessage sticks
            // around until the next successful load.
            sendErrorMessage = "Couldn't send your message. Check your connection and try again."
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw MessagingError.timedOut
            }
            guard let result = try await group.next() else {
                throw MessagingError.timedOut
            }
            group.cancelAll()
            return result
        }
    }

    private static func nameCacheKey(for userId: String) -> String {
        "meridian_family.senderName.\(userId)"
    }
}
