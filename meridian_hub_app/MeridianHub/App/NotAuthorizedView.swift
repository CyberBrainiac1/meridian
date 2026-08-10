import SwiftUI

/// Reached when the sign-in worked but the account has no `resident_hub_profile`
/// row — almost always a caregiver who typed their Meridian Care login into a
/// resident's phone. Worded so that a resident reading over their shoulder sees
/// a setup step that isn't finished, not a fault or a lockout.
struct NotAuthorizedView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeridianTouchTarget.minSpacing) {
                Image(systemName: "iphone.badge.exclamationmark")
                    .font(.system(size: 56))
                    .foregroundStyle(MeridianColor.warning)

                Text("This phone isn't set up as a room device yet")
                    .font(MeridianFont.heading())
                    .foregroundStyle(MeridianColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Text("The sign-in worked, but this account isn't the one assigned to a resident's room.")
                    .font(MeridianFont.body())
                    .foregroundStyle(MeridianColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Text("If you're a staff member: this account isn't bound to a room. Check the device binding in Meridian Care, then sign in again with the device account for this room. Your own Meridian Care login won't work here.")
                    .font(MeridianFont.body())
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Nothing is wrong with the phone, and nothing needs to be done by the person who lives here.")
                    .font(MeridianFont.body())
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await auth.signOut() }
                } label: {
                    Text("Sign out")
                        .font(MeridianFont.action())
                        .foregroundStyle(MeridianColor.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: MeridianTouchTarget.minSize)
                        .padding(.horizontal, MeridianSpacing.md)
                        .background(MeridianColor.primary, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
                }
                .buttonStyle(.plain)
                .padding(.top, MeridianSpacing.xs)
            }
            .padding(MeridianSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MeridianColor.background)
    }
}
