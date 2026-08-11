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
    /// Needed only to hand `SettingsView` the surface it styles itself from —
    /// nothing on the help panel itself reads it.
    let profile: HubProfile
    let onClose: () -> Void

    /// The unified app's auth. The Hub was a kiosk build with no way out at
    /// all, which meant a staff member re-assigning a device had to reinstall
    /// the app — see `signOutSection` for why the way out lives down here.
    @EnvironmentObject private var auth: AuthViewModel

    @State private var isConfirmingSignOut = false
    @State private var isShowingSettings = false

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
            VStack(alignment: .leading, spacing: HubSpacing.lg) {
                Text("What you can do here")
                    .font(HubFont.heading())
                    .foregroundStyle(HubColor.foreground)
                    .accessibilityAddTraits(.isHeader)

                ForEach(items) { item in
                    HStack(alignment: .top, spacing: HubSpacing.md) {
                        Image(systemName: item.symbol)
                            .font(HubFont.heading(26))
                            .foregroundStyle(HubColor.primary)
                            .frame(width: 44, alignment: .center)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: HubSpacing.xs) {
                            Text(item.title)
                                .font(HubFont.bodyStrong(24))
                                .foregroundStyle(HubColor.foreground)
                            Text(item.body)
                                .font(HubFont.body())
                                .foregroundStyle(HubColor.foregroundMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                Text("If anything is confusing or this screen is not working, press the call button by your bed or call out for staff. Someone will come.")
                    .font(HubFont.bodyStrong())
                    .foregroundStyle(HubColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(HubSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HubColor.accentWash)
                    .clipShape(RoundedRectangle(cornerRadius: HubRadius.control))

                Button(action: onClose) {
                    HStack(spacing: HubSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(HubFont.action())
                            .accessibilityHidden(true)
                        Text("Close help")
                            .font(HubFont.action())
                    }
                    .frame(maxWidth: .infinity, minHeight: HubTouchTarget.minSize + HubSpacing.lg)
                    .padding(HubSpacing.md)
                    .foregroundStyle(HubColor.primary)
                    .background(HubColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: HubRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: HubRadius.control)
                            .strokeBorder(HubColor.primary, lineWidth: 4)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close help")
                .accessibilityHint("Goes back to the main screen")
                .padding(.top, HubTouchTarget.minSpacing)

                signOutSection
            }
            .padding(HubSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(HubColor.background)
        .accessibilityLabel("What you can do on this screen")
        .confirmationDialog(
            "Sign out of this device?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This screen will stop showing this resident's reminders and help buttons until someone signs in again.")
        }
        // Same sheet reasoning as this panel itself: closed it occupies no
        // space, and it can never sit on top of Emergency help.
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(surface: .hub(profile: profile), onClose: { isShowingSettings = false })
        }
    }

    // MARK: Sign out

    /// The one staff affordance on an otherwise resident-only surface.
    ///
    /// Every rule this view is built on is inverted here on purpose. It sits
    /// behind the Help sheet, below the Close button, past everything a
    /// resident came here to read — so reaching it takes a deliberate scroll
    /// past the exit. It is small and muted rather than 60pt and high
    /// contrast, and it is the only control in the Hub that is *not* sized for
    /// a tremor: a resident must never be able to sign themselves out by
    /// accident, and looking incidental is what makes that true. The
    /// confirmation is a second gate on the same risk.
    ///
    /// It exists because the alternative — the kiosk build's no way out at
    /// all — meant re-assigning a phone to another room required reinstalling
    /// the app.
    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: HubSpacing.xs) {
            Divider()
                .overlay(HubColor.borderSoft)
                .padding(.bottom, HubSpacing.md)

            Text("For staff")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HubColor.foregroundMuted)
                .accessibilityAddTraits(.isHeader)

            // Settings sits beside sign-out and is styled exactly like it, for
            // the same reason: most of what is behind it (the alert-readiness
            // check, the account rows, the password change) is a staff errand,
            // and a resident who taps into it by accident should find nothing
            // that can hurt them. The one resident-facing control in there —
            // text size — is safe, reversible, and worth reaching if they do
            // find it, which is why this is muted rather than hidden.
            Button {
                isShowingSettings = true
            } label: {
                Text("Settings and text size")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HubColor.foregroundMuted)
                    .underline()
                    .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings and text size")
            .accessibilityHint("Alert checks, text size, and account details.")

            Button {
                isConfirmingSignOut = true
            } label: {
                Text("Sign out of this device")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HubColor.foregroundMuted)
                    .underline()
                    .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign out of this device")
            .accessibilityHint("For staff. Signs this resident out and returns to the sign-in screen.")
        }
        .padding(.top, HubSpacing.xl)
    }
}
