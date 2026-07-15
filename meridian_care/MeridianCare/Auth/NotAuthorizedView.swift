import SwiftUI

struct NotAuthorizedView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        VStack(spacing: MeridianSpacing.md) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(MeridianColor.warning)
            Text("This account isn't set up for Meridian Care")
                .font(MeridianFont.heading(20))
                .multilineTextAlignment(.center)
            Text("Care is for facility owners, admins, and caregivers. If you're a family member, use Meridian Family instead.")
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foregroundMuted)
                .multilineTextAlignment(.center)
            Button("Sign out") {
                Task { await auth.signOut() }
            }
            .buttonStyle(MeridianButtonStyle(kind: .secondary))
        }
        .padding(MeridianSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeridianColor.background)
    }
}
