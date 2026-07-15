import SwiftUI

struct NotAuthorizedView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        VStack(spacing: MeridianSpacing.md) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(MeridianColor.warning)
            Text("This account isn't linked to a resident yet")
                .font(MeridianFont.heading(20))
                .multilineTextAlignment(.center)
            Text("Ask your facility's care team to add you as a family contact. If you work at the facility, use Meridian Care instead.")
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foreground.opacity(0.7))
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
