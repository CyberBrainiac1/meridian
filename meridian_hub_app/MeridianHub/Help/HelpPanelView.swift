import SwiftUI

/// Plain-language explanation of the resident surface. Ported from the web
/// Hub's `HelpPanel`.
///
/// Written to be read cold, by someone who may have read it yesterday and not
/// remember. Deliberately NOT a coach-mark tour: no step counter, no "next",
/// no progress — nothing that implies there is a sequence to get through or a
/// state to be left in halfway. Each item stands alone, and the whole thing is
/// dismissed by one large button.
///
/// The web version expanded in place so it could never sit on top of Emergency
/// help. On a phone the equivalent is a sheet: while it is closed it occupies
/// no space at all, and while it is open it is the only thing the resident is
/// being asked to deal with.
struct HelpPanelView: View {
    let onClose: () -> Void

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let body: String
    }

    private let items: [Item] = [
        Item(
            id: "assistance",
            symbol: "hand.raised.fill",
            title: "Request assistance",
            body: "Press this when you would like a caregiver to come to your room. It is not an emergency — use it for anything you need help with."
        ),
        Item(
            id: "family",
            symbol: "phone.fill",
            title: "Call family",
            body: "This lets your family know you would like to speak with them. They will be told you asked, and they will call you."
        ),
        Item(
            id: "emergency",
            symbol: "bell.fill",
            title: "Emergency help",
            body: "Press this if you need help right away. It reaches the care team faster than anything else on this screen. You can always press it, even while you are waiting for something else."
        ),
        Item(
            id: "visitor",
            symbol: "person.crop.circle.badge.checkmark",
            title: "Visitor check",
            body: "If someone we do not recognise comes to the door, this screen will ask if you were expecting them. If you are not sure, choose “No, get help”. Nobody will mind."
        ),
        Item(
            id: "reminders",
            symbol: "pills.fill",
            title: "Today's reminders",
            body: "This screen lists what's coming up today, including your medication. Tap a reminder once you've done it. If you forget to tap, nothing bad happens — a caregiver still checks."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeridianSpacing.lg) {
                Text("What you can do here")
                    .font(MeridianFont.heading())
                    .foregroundStyle(MeridianColor.foreground)
                    .accessibilityAddTraits(.isHeader)

                ForEach(items) { item in
                    HStack(alignment: .top, spacing: MeridianSpacing.md) {
                        Image(systemName: item.symbol)
                            .font(MeridianFont.heading(26))
                            .foregroundStyle(MeridianColor.primary)
                            .frame(width: 44, alignment: .center)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                            Text(item.title)
                                .font(MeridianFont.bodyStrong(24))
                                .foregroundStyle(MeridianColor.foreground)
                            Text(item.body)
                                .font(MeridianFont.body())
                                .foregroundStyle(MeridianColor.foregroundMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                Text("If anything is confusing or this screen is not working, press the call button by your bed or call out for staff. Someone will come.")
                    .font(MeridianFont.bodyStrong())
                    .foregroundStyle(MeridianColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(MeridianSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MeridianColor.accentWash)
                    .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))

                Button(action: onClose) {
                    HStack(spacing: MeridianSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(MeridianFont.action())
                            .accessibilityHidden(true)
                        Text("Close help")
                            .font(MeridianFont.action())
                    }
                    .frame(maxWidth: .infinity, minHeight: MeridianTouchTarget.minSize + MeridianSpacing.lg)
                    .padding(MeridianSpacing.md)
                    .foregroundStyle(MeridianColor.primary)
                    .background(MeridianColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: MeridianRadius.control)
                            .strokeBorder(MeridianColor.primary, lineWidth: 4)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close help")
                .accessibilityHint("Goes back to the main screen")
                .padding(.top, MeridianTouchTarget.minSpacing)
            }
            .padding(MeridianSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MeridianColor.background)
        .accessibilityLabel("What you can do on this screen")
    }
}
