import SwiftUI

/// The first frame after launch, shown while we work out whether there is
/// already a session.
///
/// It matches the launch screen's background exactly, so the handoff from the
/// system launch image to the first real frame is invisible — the app appears
/// to open straight into content rather than flashing between two screens.
/// The spinner is delayed: showing one instantly makes a fast launch feel
/// slower than it is, because a spinner that appears and vanishes reads as a
/// stutter.
struct RestoringView: View {
    @State private var showSpinner = false

    var body: some View {
        VStack(spacing: AuthStyle.tightGap) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AuthStyle.primary)
            Text("Meridian")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(AuthStyle.foreground)

            if showSpinner {
                ProgressView()
                    .padding(.top, AuthStyle.tightGap)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AuthStyle.background.ignoresSafeArea())
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation { showSpinner = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Meridian is starting")
    }
}
