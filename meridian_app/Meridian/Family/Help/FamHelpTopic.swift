import Foundation

/// One screen of a guided tour. Content lives here rather than in the view
/// so the wording is reviewable in one place — the privacy copy in
/// particular is a product commitment, not UI filler.
struct FamHelpStep: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let symbol: String
}

/// The three things a family member actually asks about the first time they
/// open this app: what they'll be told, who visited, and what the facility
/// can and can't share. One topic per tab, opened from that tab's "?".
enum FamHelpTopic: Identifiable, CaseIterable {
    case updates
    case visitors
    case privacy

    var id: Self { self }

    var title: String {
        switch self {
        case .updates: return "Staying informed"
        case .visitors: return "Visitors"
        case .privacy: return "Privacy and consent"
        }
    }

    var steps: [FamHelpStep] {
        switch self {
        case .updates:
            return [
                FamHelpStep(
                    title: "You'll hear when it matters",
                    body: "Meridian tells you about falls and health events involving your family member. You won't get a notification every time they walk to the kitchen.",
                    symbol: "bell.fill"
                ),
                FamHelpStep(
                    title: "Staff respond first",
                    body: "Care staff are alerted the moment something happens and respond in person. What you see here is the same record they're working from.",
                    symbol: "figure.walk.motion"
                ),
                FamHelpStep(
                    title: "What 'resolved' means",
                    body: "A caregiver reached your family member, checked on them, and closed the alert. If you want detail beyond what's shown, call the facility.",
                    symbol: "checkmark.seal.fill"
                )
            ]
        case .visitors:
            return [
                FamHelpStep(
                    title: "Who came to see them",
                    body: "When someone the system doesn't recognise arrives, it's logged here with the time.",
                    symbol: "person.text.rectangle.fill"
                ),
                FamHelpStep(
                    title: "Your family member is asked, not overruled",
                    body: "If an unfamiliar visitor appears, the tablet in their room asks whether they were expecting someone. They can always say no.",
                    symbol: "questionmark.bubble.fill"
                )
            ]
        case .privacy:
            return [
                FamHelpStep(
                    title: "You see what your family member allowed",
                    body: "Their consent controls this app. If they withdraw it, this feed stops — that's by design, not a fault.",
                    symbol: "lock.shield.fill"
                ),
                FamHelpStep(
                    title: "Cameras never leave the building",
                    body: "Video is processed in the facility and discarded. It is never stored, and it is never sent to you or to us.",
                    symbol: "eye.slash.fill"
                ),
                FamHelpStep(
                    title: "You control your own text alerts",
                    body: "Turn SMS escalation on or off here at any time. It only ever fires for critical alerts nobody has responded to.",
                    symbol: "message.badge.filled.fill"
                )
            ]
        }
    }
}
