import Foundation
import UserNotifications

/// Fires a local notification the moment a caregiver's device learns about a
/// new open, non-info incident — the audible/lock-screen counterpart to
/// CareRootView's full-screen UrgentAlertOverlay.
///
/// Platform ceiling, stated plainly: this is a LOCAL notification, scheduled
/// by the app itself from data it already has (the realtime feed). It is not
/// remote push, and it is not an iOS Critical Alert.
///   - Critical Alerts (the interruption level that bypasses Silent Mode and
///     Do Not Disturb entirely) require the com.apple.developer.usernotifications.
///     critical-alerts entitlement, which Apple grants only to apps under a
///     paid Apple Developer Program membership, via a separate approval
///     request — unavailable on this project's free "Personal Team" signing.
///   - `.timeSensitive` is the strongest interruption level actually
///     available here. It breaks through most Focus/Do Not Disturb
///     configurations (a user can still explicitly exclude Time Sensitive
///     notifications in their own Focus settings) and is visually/audibly
///     distinct from a normal notification, but it still respects the
///     physical ringer/silent switch — nothing on iOS without the Critical
///     Alert entitlement can force sound through a muted phone.
///   - Because this is local, not push, it only fires while this process is
///     alive: foreground, or briefly backgrounded. An incident that arrives
///     while MeridianCare has been fully terminated by the user or the OS
///     will not notify until the app is reopened and the feed refreshes. A
///     background-safe "even when closed" alert needs real APNs push
///     triggered server-side, which needs the same paid membership as above.
@MainActor
final class AlertNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertNotificationService()

    // Plain string constants, safe from any isolation context — explicitly
    // nonisolated because static members of a @MainActor class otherwise
    // inherit MainActor isolation, and the delegate callbacks below run
    // nonisolated (they're invoked directly by UNUserNotificationCenter).
    nonisolated static let categoryId = "URGENT_INCIDENT"
    nonisolated static let medicationCategoryId = "MEDICATION_DUE"
    nonisolated static let activityCategoryId = "ACTIVITY_DUE"
    nonisolated static let assistanceCategoryId = "ASSISTANCE_REQUEST"
    private nonisolated static let acknowledgeActionId = "ACKNOWLEDGE_ACTION"
    private nonisolated static let viewActionId = "VIEW_ACTION"
    private nonisolated static let markGivenActionId = "MARK_GIVEN_ACTION"
    private nonisolated static let markDoneActionId = "MARK_DONE_ACTION"
    private nonisolated static let assistanceAcknowledgeActionId = "ASSISTANCE_ACKNOWLEDGE_ACTION"
    private nonisolated static let assistanceViewActionId = "ASSISTANCE_VIEW_ACTION"
    private nonisolated static let incidentIdKey = "incidentId"
    private nonisolated static let medicationIdKey = "medicationId"
    private nonisolated static let activityIdKey = "activityId"
    private nonisolated static let scheduledForKey = "scheduledFor"
    private nonisolated static let assistanceRequestIdKey = "assistanceRequestId"

    /// Set by CareRootView so a notification tap (or its "View" action) can jump
    /// straight to that incident's detail screen — the same
    /// `pendingOpenIncidentId` binding UrgentAlertOverlay's "View alert"
    /// button already drives.
    var onOpenIncident: ((String) -> Void)?

    /// Set by CareRootView so an assistance-request notification tap (or its
    /// "View" action) can jump to where that request is visible. Mirrors
    /// `onOpenIncident`'s shape; see CareRootView for the current (deliberately
    /// minimal) navigation behavior this drives.
    var onOpenAssistanceRequest: ((String) -> Void)?

    /// Every incident id a notification has already been scheduled for this
    /// launch. AlertFeedViewModel does its own newly-appeared diffing before
    /// calling notify(for:copy:); this is a second, cheaper guard against
    /// re-firing for the same incident on a later refresh (e.g. a status
    /// change from open -> acknowledged still matches "not yet notified"
    /// only once).
    private var notifiedIncidentIds: Set<String> = []

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Call once at launch. Requesting `.timeSensitive` here is what allows
    /// this app to actually use that interruption level — omit it and iOS
    /// silently downgrades every notification this app sends to `.active`.
    func requestAuthorizationAndRegisterCategory() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]) { _, _ in
            // No user-facing handling on denial: the in-app UrgentAlertOverlay
            // remains the primary alert path regardless of notification
            // permission, so a caregiver who declines isn't left with nothing.
        }

        let acknowledge = UNNotificationAction(
            identifier: Self.acknowledgeActionId,
            title: "Acknowledge",
            options: []
        )
        let view = UNNotificationAction(
            identifier: Self.viewActionId,
            title: "View alert",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryId,
            actions: [acknowledge, view],
            intentIdentifiers: [],
            options: [.hiddenPreviewsShowTitle]
        )

        // Medication reminders are a separate category so they get their own
        // action ("Mark given" writes an administration row, not an incident
        // acknowledgement) and so a caregiver can mute one class of alert in
        // iOS Settings without muting falls.
        let markGiven = UNNotificationAction(
            identifier: Self.markGivenActionId,
            title: "Mark given",
            options: []
        )
        let medicationCategory = UNNotificationCategory(
            identifier: Self.medicationCategoryId,
            actions: [markGiven],
            intentIdentifiers: [],
            options: [.hiddenPreviewsShowTitle]
        )

        // Daily care activities (meals, walks, and similar) are a third,
        // separate category — its own action ("Mark done" writes a
        // completion row, not an administration or an incident
        // acknowledgement) so a caregiver can mute this class of alert in
        // iOS Settings independently of medications and falls.
        let markDone = UNNotificationAction(
            identifier: Self.markDoneActionId,
            title: "Mark done",
            options: []
        )
        let activityCategory = UNNotificationCategory(
            identifier: Self.activityCategoryId,
            actions: [markDone],
            intentIdentifiers: [],
            options: [.hiddenPreviewsShowTitle]
        )

        // Assistance requests share the same acknowledge/view semantics as
        // incidents (unlike medication/activity's single "mark done" action),
        // since they can be genuinely as urgent — a resident pressing
        // Emergency gets the same two-action shape as a fall alert.
        let assistanceAcknowledge = UNNotificationAction(
            identifier: Self.assistanceAcknowledgeActionId,
            title: "Acknowledge",
            options: []
        )
        let assistanceView = UNNotificationAction(
            identifier: Self.assistanceViewActionId,
            title: "View",
            options: [.foreground]
        )
        let assistanceCategory = UNNotificationCategory(
            identifier: Self.assistanceCategoryId,
            actions: [assistanceAcknowledge, assistanceView],
            intentIdentifiers: [],
            options: [.hiddenPreviewsShowTitle]
        )

        center.setNotificationCategories([category, medicationCategory, activityCategory, assistanceCategory])
    }

    /// Deliberately consults NO preference. `CareNotificationTier.falls` has
    /// no off switch in Settings, and this is the method that guarantee is
    /// made of — see `CareNotificationTier.canBeDisabled`.
    func notify(for incident: IncidentEvent, copy: String) {
        guard !notifiedIncidentIds.contains(incident.id) else { return }
        notifiedIncidentIds.insert(incident.id)

        let content = UNMutableNotificationContent()
        content.title = incident.severity == .critical ? "Critical alert — \(incident.roomId ?? "Unknown room")" : "Alert — \(incident.roomId ?? "Unknown room")"
        content.body = copy
        content.sound = UNNotificationSound(named: UNNotificationSoundName("urgent_alert.caf"))
        content.interruptionLevel = .timeSensitive
        // Puts this notification ahead of routine ones in a Time Sensitive
        // stack; 100 is Apple's documented max for relevanceScore.
        content.relevanceScore = 1.0
        content.categoryIdentifier = Self.categoryId
        content.userInfo = [Self.incidentIdKey: incident.id]

        let request = UNNotificationRequest(identifier: incident.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// A resolved/dismissed/re-escalated incident can fire again later as a
    /// genuinely new event — clearing it here (called from the same place
    /// UrgentAlertOverlay's dismiss state would reset) keeps that possible
    /// without a full app relaunch.
    func forgetIncident(_ incidentId: String) {
        notifiedIncidentIds.remove(incidentId)
    }

    /// Fires when a scheduled dose comes due. Deliberately `.timeSensitive`
    /// like a fall alert but WITHOUT the klaxon — a medication pass is
    /// time-critical, not an emergency, and giving both the same sound would
    /// train caregivers to discount the fall alarm.
    ///
    /// Honours the caregiver's Settings choice for this tier. The check is
    /// here rather than at the watcher's call site so every future caller
    /// inherits it, and it sits BEFORE the dedupe insert so a tier that is
    /// muted now and unmuted later can still fire for a dose that is still due.
    func notifyMedicationDue(_ dose: MedicationDose) {
        guard CareNotificationPreferences.shared.isEnabled(.medication) else { return }
        guard !notifiedIncidentIds.contains(dose.id) else { return }
        notifiedIncidentIds.insert(dose.id)

        let content = UNMutableNotificationContent()
        let room = dose.roomId.map { "Room \($0)" } ?? dose.residentName
        content.title = dose.isOverdue ? "Medication overdue — \(room)" : "Medication due — \(room)"
        content.body = "\(dose.residentName): \(dose.medicationName) \(dose.dose) at \(MeridianFormat.clockTime(dose.scheduledFor))"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.medicationCategoryId
        content.userInfo = [
            Self.medicationIdKey: dose.medicationId,
            Self.scheduledForKey: ISO8601DateFormatter().string(from: dose.scheduledFor),
        ]

        let request = UNNotificationRequest(identifier: dose.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Fires when a scheduled activity (meal, walk, and similar) comes due.
    /// Deliberately `.timeSensitive` like a fall alert but WITHOUT the
    /// klaxon — same reasoning as notifyMedicationDue: an overdue meal is
    /// not an emergency, and giving both the same sound would train
    /// caregivers to discount the fall alarm.
    ///
    /// Honours the caregiver's Settings choice for this tier, same shape as
    /// notifyMedicationDue.
    func notifyActivityDue(_ slot: ActivitySlot) {
        guard CareNotificationPreferences.shared.isEnabled(.activity) else { return }
        guard !notifiedIncidentIds.contains(slot.id) else { return }
        notifiedIncidentIds.insert(slot.id)

        let content = UNMutableNotificationContent()
        let room = slot.roomId.map { "Room \($0)" } ?? slot.residentName
        content.title = slot.isOverdue ? "\(slot.label) overdue — \(room)" : "\(slot.label) — \(room)"
        content.body = "\(slot.residentName): \(slot.label) at \(MeridianFormat.clockTime(slot.scheduledFor))"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.activityCategoryId
        content.userInfo = [
            Self.activityIdKey: slot.activityId,
            Self.scheduledForKey: ISO8601DateFormatter().string(from: slot.scheduledFor),
        ]

        let request = UNNotificationRequest(identifier: slot.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Fourth notification tier, for resident-initiated assistance requests
    /// (MeridianHub's Request assistance / Call family / Emergency help
    /// buttons). Unlike medication/activity, urgency varies by
    /// CareAssistanceKind rather than being fixed for the whole tier:
    ///   - `.emergency` — a resident pressing Emergency is genuinely as
    ///     urgent as a detected fall, so it gets the SAME klaxon
    ///     (`urgent_alert.caf`) and max relevanceScore as notify(for:copy:).
    ///   - `.assistance` / `.familyContact` — routine, `.default` sound,
    ///     same reasoning already established for medication/activity: a
    ///     routine request must not sound like the fall alarm or caregivers
    ///     learn to discount it.
    /// Both use `.timeSensitive` and share `notifiedIncidentIds` for dedup —
    /// an assistance request id and an incident id can never collide, they
    /// come from different UUID columns.
    ///
    /// The Settings toggle for this tier ("Resident requests") governs the
    /// routine kinds ONLY. An `.emergency` press is a resident saying they
    /// need help right now, which is the same claim a detected fall makes, so
    /// it rides the always-on "Falls & emergencies" guarantee and ignores the
    /// preference entirely. A caregiver muting routine call-bells must not
    /// silently mute the emergency button as well.
    func notifyAssistanceRequest(_ assistanceRequest: AssistanceRequest, copy: String) {
        let isEmergency = assistanceRequest.requestKind == .emergency
        guard isEmergency || CareNotificationPreferences.shared.isEnabled(.assistance) else { return }
        guard !notifiedIncidentIds.contains(assistanceRequest.id) else { return }
        notifiedIncidentIds.insert(assistanceRequest.id)

        let content = UNMutableNotificationContent()
        content.title = isEmergency
            ? "Emergency — Room \(assistanceRequest.roomId)"
            : "\(assistanceRequest.requestKind.label) — Room \(assistanceRequest.roomId)"
        content.body = copy
        content.sound = isEmergency
            ? UNNotificationSound(named: UNNotificationSoundName("urgent_alert.caf"))
            : .default
        content.interruptionLevel = .timeSensitive
        if isEmergency {
            // Same ceiling notify(for:copy:) uses — 100 is Apple's
            // documented max for relevanceScore, expressed here as 1.0.
            content.relevanceScore = 1.0
        }
        content.categoryIdentifier = Self.assistanceCategoryId
        content.userInfo = [Self.assistanceRequestIdKey: assistanceRequest.id]

        let notificationRequest = UNNotificationRequest(
            identifier: assistanceRequest.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(notificationRequest)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Without this, iOS suppresses banner/sound for a notification fired
    /// while the app is frontmost — exactly the moment a caregiver is
    /// already looking at the phone but perhaps not at MeridianCare.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        // Assistance request: checked first, before the
        // incident/medication/activity branches, since an assistance
        // notification's userInfo carries none of those keys — same
        // ordering discipline as the activity branch below.
        if let assistanceRequestId = userInfo[Self.assistanceRequestIdKey] as? String {
            switch response.actionIdentifier {
            case Self.assistanceAcknowledgeActionId:
                _ = await AssistanceActionService.respond(
                    assistanceRequestId: assistanceRequestId,
                    newStatus: .acknowledged
                )
            case Self.assistanceViewActionId, UNNotificationDefaultActionIdentifier:
                await MainActor.run { self.onOpenAssistanceRequest?(assistanceRequestId) }
            default:
                break
            }
            return
        }

        // Activity reminder: "Mark done" records the completion straight
        // from the lock screen, the same RPC the resident detail screen
        // calls. Checked before the medication/incident branches since an
        // activity notification's userInfo carries neither of those keys.
        if let activityId = userInfo[Self.activityIdKey] as? String,
           let scheduledRaw = userInfo[Self.scheduledForKey] as? String,
           let scheduledFor = ISO8601DateFormatter().date(from: scheduledRaw) {
            if response.actionIdentifier == Self.markDoneActionId {
                _ = await ActivityActionService.record(
                    activityId: activityId,
                    scheduledFor: scheduledFor,
                    status: .done
                )
            }
            return
        }

        // Medication reminder: "Mark given" records the administration
        // straight from the lock screen, the same RPC the resident detail
        // screen calls.
        if let medicationId = userInfo[Self.medicationIdKey] as? String,
           let scheduledRaw = userInfo[Self.scheduledForKey] as? String,
           let scheduledFor = ISO8601DateFormatter().date(from: scheduledRaw) {
            if response.actionIdentifier == Self.markGivenActionId {
                _ = await MedicationActionService.record(
                    medicationId: medicationId,
                    scheduledFor: scheduledFor,
                    status: .given
                )
            }
            return
        }

        guard let incidentId = userInfo[Self.incidentIdKey] as? String else { return }

        switch response.actionIdentifier {
        case Self.acknowledgeActionId:
            _ = await IncidentActionService.respond(incidentId: incidentId, newStatus: .acknowledged)
        case Self.viewActionId, UNNotificationDefaultActionIdentifier:
            await MainActor.run { self.onOpenIncident?(incidentId) }
        default:
            break
        }
    }
}
