import Foundation

/// One screen of a guided tour. Plain data, so the copy stays reviewable in
/// one place — this is training material for people who may be learning the
/// app halfway through a shift, not decoration around the UI.
struct HelpStep: Identifiable, Equatable {
    /// Titles are unique within a topic and read better than an index in
    /// accessibility output, so they double as the identity.
    var id: String { title }
    let title: String
    let body: String
    let systemImage: String
}

/// The screens a caregiver can be standing on when they tap "?". Each tour
/// answers "what do these buttons actually do" in the words the floor uses,
/// including the parts that are easy to get wrong (Resolve vs Dismissed,
/// what Escalate sets off, why a refusal still has to be recorded).
enum HelpTopic: String, Identifiable, CaseIterable {
    case alerts
    case handoff
    case residents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alerts: return "Responding to alerts"
        case .handoff: return "Shift handoff"
        case .residents: return "Resident profiles"
        }
    }

    var steps: [HelpStep] {
        switch self {
        case .alerts: return Self.alertSteps
        case .handoff: return Self.handoffSteps
        case .residents: return Self.residentSteps
        }
    }

    private static let alertSteps: [HelpStep] = [
        HelpStep(
            title: "Alerts find you",
            body: "You don't go looking for them. A red full-screen alert means someone needs help now. Falls also play an alarm tone, even if the app is in your pocket.",
            systemImage: "bell.badge"
        ),
        HelpStep(
            title: "Acknowledge means 'I've got this'",
            body: "It tells the rest of the team someone is responding, and it starts the clock the facility reports on. It does not mean the incident is finished.",
            systemImage: "checkmark.circle"
        ),
        HelpStep(
            title: "Resolve when the resident is safe",
            body: "Only after you've seen them. If it turned out to be nothing, use Dismissed (false alarm) instead — that keeps the fall-detection accuracy honest.",
            systemImage: "checkmark.seal"
        ),
        HelpStep(
            title: "Escalate calls for backup",
            body: "It notifies the on-call nurse and the facility director. You'll be asked to confirm, because it pulls other people out of what they're doing.",
            systemImage: "exclamationmark.triangle"
        ),
        HelpStep(
            title: "If two of you respond at once",
            body: "That's fine. The first tap wins and the second is told what already happened. Nothing gets double-logged.",
            systemImage: "person.2"
        )
    ]

    private static let handoffSteps: [HelpStep] = [
        HelpStep(
            title: "Who's on now, and who's next",
            body: "The top of the screen shows the current shift and the one after it. Tap the phone icon to call them directly.",
            systemImage: "person.crop.circle.badge.clock"
        ),
        HelpStep(
            title: "Notes from the shift before you",
            body: "Urgent notes sort to the top. These are the things the last caregiver needed you to know and couldn't put in a chart.",
            systemImage: "note.text"
        ),
        HelpStep(
            title: "Acknowledge what you've read",
            body: "It's how the outgoing caregiver knows the message actually landed. Nothing is assumed to have been passed on.",
            systemImage: "checkmark.bubble"
        ),
        HelpStep(
            title: "The last 8 hours, automatically",
            body: "Below the notes is every incident from the previous shift — not a summary someone wrote, the actual record.",
            systemImage: "clock.arrow.circlepath"
        )
    ]

    private static let residentSteps: [HelpStep] = [
        HelpStep(
            title: "Check before you act",
            body: "Allergies and code status are at the top of every profile, in red. Read them before you respond to anything, especially if you're covering a floor you don't normally work.",
            systemImage: "heart.text.square"
        ),
        HelpStep(
            title: "Today's medications",
            body: "Times, doses and instructions, with anything overdue marked. Tap a dose to record it as Given, Refused or Held.",
            systemImage: "pills"
        ),
        HelpStep(
            title: "Refused and Held are not failures",
            body: "They're clinically meaningful. Record what actually happened — a blank is worse than a refusal.",
            systemImage: "hand.raised"
        ),
        HelpStep(
            title: "Emergency contacts",
            body: "The primary contact is listed first. Tap to call from the app.",
            systemImage: "phone.arrow.up.right"
        )
    ]
}
