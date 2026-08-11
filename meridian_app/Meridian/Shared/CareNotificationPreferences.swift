import Foundation
import SwiftUI

/// The four notification tiers `AlertNotificationService` schedules, as
/// something a caregiver can see and (mostly) control.
///
/// One case per `UNNotificationCategory` the service registers, so a tier can
/// never drift out of sync with a category that actually exists.
enum CareNotificationTier: String, CaseIterable, Identifiable {
    /// `AlertNotificationService.categoryId` — detected incidents, plus a
    /// resident pressing Emergency on the Hub.
    case falls
    /// `AlertNotificationService.medicationCategoryId`
    case medication
    /// `AlertNotificationService.activityCategoryId`
    case activity
    /// `AlertNotificationService.assistanceCategoryId`, routine requests only.
    case assistance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .falls: return "Falls & emergencies"
        case .medication: return "Medication"
        case .activity: return "Daily activities"
        case .assistance: return "Resident requests"
        }
    }

    var detail: String {
        switch self {
        case .falls:
            return "Detected falls, and a resident pressing Emergency. Always on — see below."
        case .medication:
            return "A dose coming due or going overdue."
        case .activity:
            return "Meals, walks and other scheduled care."
        case .assistance:
            return "A resident asking for help or for a family call. Emergency presses always come through regardless of this setting."
        }
    }

    var symbol: String {
        switch self {
        case .falls: return "exclamationmark.octagon.fill"
        case .medication: return "pills.fill"
        case .activity: return "figure.walk"
        case .assistance: return "hand.raised.fill"
        }
    }

    /// Falls are the one tier with no off switch.
    ///
    /// This is the entire reason this app exists on a caregiver's phone. A
    /// toggle that can silence fall alerts is a toggle that will eventually be
    /// found switched off by someone who was annoyed during a night shift, and
    /// nobody will notice until a resident is on the floor. It is rendered as
    /// an always-on statement with an explanation rather than a disabled
    /// toggle, because a greyed-out switch reads as "broken" and invites
    /// someone to go hunting for the real one.
    var canBeDisabled: Bool { self != .falls }
}

/// Per-caregiver notification preferences, persisted to `UserDefaults` and
/// honoured by `AlertNotificationService` before it schedules anything.
///
/// Keyed per signed-in user, not per device: Care phones are shared across a
/// shift, and one caregiver's choice to mute meal reminders must not follow
/// the handset to the next person.
@MainActor
final class CareNotificationPreferences: ObservableObject {
    static let shared = CareNotificationPreferences()

    /// Nil until `bindToSignedInUser()` resolves a session.
    @Published private(set) var userId: String?
    @Published private var enabledByTier: [CareNotificationTier: Bool] = [:]

    private init() {}

    /// Call from the Care surface's root as soon as it appears. Cheap and
    /// idempotent — a repeat call with the same user is a no-op.
    func bindToSignedInUser() {
        let resolved = SupabaseManager.client.auth.currentUser?.id.uuidString
        guard resolved != userId else { return }
        userId = resolved
        reload()
    }

    /// Fails OPEN. Before a user is resolved, or for a tier that was never
    /// written, every tier is on — an unknown preference must never be the
    /// reason a caregiver misses a dose.
    func isEnabled(_ tier: CareNotificationTier) -> Bool {
        guard tier.canBeDisabled else { return true }
        return enabledByTier[tier] ?? true
    }

    func setEnabled(_ isOn: Bool, for tier: CareNotificationTier) {
        guard tier.canBeDisabled else { return }
        enabledByTier[tier] = isOn
        guard let userId else { return }
        UserDefaults.standard.set(isOn, forKey: Self.key(for: tier, userId: userId))
    }

    private func reload() {
        guard let userId else {
            enabledByTier = [:]
            return
        }
        var next: [CareNotificationTier: Bool] = [:]
        for tier in CareNotificationTier.allCases where tier.canBeDisabled {
            // `object(forKey:)` rather than `bool(forKey:)` — the latter
            // cannot tell "explicitly muted" from "never set", and the default
            // for never-set has to be on.
            next[tier] = UserDefaults.standard.object(forKey: Self.key(for: tier, userId: userId)) as? Bool ?? true
        }
        enabledByTier = next
    }

    private static func key(for tier: CareNotificationTier, userId: String) -> String {
        "meridian.care.notifications.\(tier.rawValue).\(userId)"
    }
}
