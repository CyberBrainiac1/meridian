import SwiftUI

/// Shown when an account signs in successfully but matches none of the three
/// interfaces — no bound resident device, no staff membership, no family link.
///
/// This is a real state, not a defensive impossibility: an account can be
/// created before anyone links it to anything. Saying so plainly beats
/// dropping someone into an empty caregiver screen and letting them conclude
/// the app is broken.
struct NotAuthorizedView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        VStack(spacing: AuthStyle.gap) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(AuthStyle.primary)

            Text("This account isn't set up yet")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(AuthStyle.foreground)
                .multilineTextAlignment(.center)

            Text("You signed in, but this account hasn't been linked to a resident, a family member, or a care team yet. A staff member can finish setting it up.")
                .font(.system(size: 18))
                .foregroundStyle(AuthStyle.foregroundMuted)
                .multilineTextAlignment(.center)

            Button("Sign out") {
                Task { await auth.signOut() }
            }
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: AuthStyle.minTarget)
            .background(AuthStyle.primary, in: RoundedRectangle(cornerRadius: AuthStyle.radius))

            Spacer()
        }
        .padding(AuthStyle.gap)
        .frame(maxWidth: .infinity)
        .background(AuthStyle.background.ignoresSafeArea())
    }
}
