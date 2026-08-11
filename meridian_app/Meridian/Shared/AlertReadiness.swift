import Foundation
import Network
import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Live diagnostic for "can an alert actually reach this person right now".
///
/// This section exists because a fall-detection app with notifications
/// disabled is silently broken: everything on screen still looks correct, the
/// feed still refreshes, the app still says it is watching — and then a
/// resident falls at 3am and nothing makes a sound. Nobody discovers that
/// state until the moment it costs something. There is no toggle here on
/// purpose; it is a mirror, and the only action it offers is the one that
/// fixes the problem (opening iOS Settings).
///
/// It reports three things, and each is a genuine independent failure mode:
///   1. Notification authorization — denied means no banner, no sound, ever.
///   2. Time-Sensitive delivery — `AlertNotificationService` sends every alert
///      at `.timeSensitive`, which is the strongest interruption level this
///      app can reach without the Critical Alert entitlement. A user (or a
///      Focus configuration) can switch that off per-app, which quietly
///      demotes fall alerts to ordinary notifications that a Focus will hold
///      back.
///   3. Connection — alerts are read from a realtime feed, so an offline
///      device has nothing to notify about in the first place.
@MainActor
final class AlertReadinessModel: ObservableObject {
    /// Pass/attention is stated in words and an icon, never colour alone.
    enum Verdict {
        case pass
        case attention
        case unknown

        var symbol: String {
            switch self {
            case .pass: return "checkmark.circle.fill"
            case .attention: return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }

        var word: String {
            switch self {
            case .pass: return "Ready"
            case .attention: return "Needs attention"
            case .unknown: return "Checking"
            }
        }
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus?
    @Published private(set) var timeSensitiveSetting: UNNotificationSetting?
    @Published private(set) var isOnline = true

    /// Created fresh in `start()`. `NWPathMonitor.cancel()` is terminal — a
    /// cancelled monitor cannot be restarted — so re-opening this screen has
    /// to build a new one rather than reuse the old.
    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.meridiansuite.app.alert-readiness")

    func start() {
        Task { await refresh() }

        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = online
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }

    /// Re-read on every appearance and every return to the foreground: the
    /// whole point of the "Open iOS Settings" button is that the answer
    /// changes outside this app, and a stale "Needs attention" after someone
    /// has just fixed it teaches them to distrust the check.
    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        timeSensitiveSetting = settings.timeSensitiveSetting
    }

    // MARK: Verdicts

    var notificationsVerdict: Verdict {
        switch authorizationStatus {
        case .none: return .unknown
        case .some(.authorized), .some(.provisional), .some(.ephemeral): return .pass
        default: return .attention
        }
    }

    var notificationsDetail: String {
        switch authorizationStatus {
        case .none:
            return "Checking whether this device is allowed to show alerts."
        case .some(.authorized):
            return "Alerts can reach this device."
        case .some(.provisional):
            return "Alerts arrive quietly, in the notification list only — they will not make a sound."
        case .some(.ephemeral):
            return "Alerts can reach this device for now."
        case .some(.notDetermined):
            return "This device has not been asked yet, so alerts cannot reach you. Fall alerts will not appear or make a sound until notifications are allowed."
        default:
            return "Notifications are turned off for Meridian. Fall alerts cannot reach this device — they will not appear on the lock screen and they will not make a sound."
        }
    }

    /// True when the right action is to show the in-app iOS permission dialog.
    /// An app that has never requested permission does not appear in iOS Settings
    /// at all, so "Open iOS Settings" is the wrong call for this state.
    var needsPermissionRequest: Bool {
        authorizationStatus == .some(.notDetermined)
    }

    /// True when the fix is "go to iOS Settings" — i.e. the user already
    /// denied or restricted permission, so only iOS can reverse it.
    var needsSystemSettings: Bool {
        switch authorizationStatus {
        case .some(.authorized), .some(.provisional), .some(.ephemeral),
             .some(.notDetermined), .none:
            return false
        default:
            return true
        }
    }

    /// Request authorization for the first time. Calling this when status is
    /// not `.notDetermined` is a no-op (iOS will not show the dialog twice).
    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
        await refresh()
    }

    var timeSensitiveVerdict: Verdict {
        switch timeSensitiveSetting {
        case .none: return .unknown
        case .some(.enabled): return .pass
        case .some(.notSupported): return .unknown
        default: return .attention
        }
    }

    var timeSensitiveDetail: String {
        switch timeSensitiveSetting {
        case .none:
            return "Checking whether urgent alerts can break through Focus."
        case .some(.enabled):
            return "Urgent alerts break through most Focus and Do Not Disturb settings."
        case .some(.notSupported):
            return "This device does not report Time-Sensitive delivery."
        default:
            return "Time-Sensitive delivery is off, so a Focus or Do Not Disturb can hold fall alerts back until later."
        }
    }

    var connectionVerdict: Verdict {
        isOnline ? .pass : .attention
    }

    var connectionDetail: String {
        isOnline
            ? "This device has a network connection, so new alerts can arrive."
            : "This device is offline. Nothing new can arrive until the connection comes back."
    }

    // MARK: Actions

    func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
