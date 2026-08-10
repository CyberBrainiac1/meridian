import Foundation
import Supabase
import UserNotifications

/// "Instant push/SMS for confirmed emergencies, with a visible resolution
/// follow-up." True APNs push needs server-side device-token registration,
/// an Apple Developer Program account, and APNs credentials — none of
/// which exist in this environment and can't be stood up as a frontend-only
/// change (frontendguytodo.md scopes real push wiring as a followup, not
/// part of the backend contract). What's real and demoable today: the
/// `notifications` table poll (source of truth per the contract) plus a
/// local on-device notification fired the moment a new emergency row is
/// seen — genuinely fires live during a foregrounded/backgrounded demo,
/// but is not a substitute for production APNs delivery when the app is
/// fully killed. Flagging this gap explicitly rather than claiming push
/// is production-ready.
@MainActor
final class UpdatesViewModel: ObservableObject {
    @Published private(set) var notifications: [FamNotificationRow] = []
    @Published var errorMessage: String?
    private var pollTask: Task<Void, Never>?
    private var seenIds = Set<String>()
    private var isFirstLoad = true

    func start() {
        guard pollTask == nil else { return }
        requestNotificationPermission()
        pollTask = Task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func load() async {
        do {
            let rows: [FamNotificationRow] = try await SupabaseManager.client
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            if !isFirstLoad {
                let newRows = rows.filter { !seenIds.contains($0.id) }
                for row in newRows {
                    fireLocalNotification(for: row)
                }
            }
            seenIds = Set(rows.map(\.id))
            isFirstLoad = false

            notifications = rows
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load updates."
        }
    }

    private func fireLocalNotification(for row: FamNotificationRow) {
        let content = UNMutableNotificationContent()
        content.title = row.incidentId != nil ? "Meridian update" : "New visitor"
        content.body = row.body
        content.sound = .default
        let request = UNNotificationRequest(identifier: row.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
