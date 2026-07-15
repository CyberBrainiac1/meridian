import SwiftUI

/// Explicit privacy controls — makes the "families never see live video"
/// boundary visible and legible. There is deliberately no video player
/// component anywhere in this app (not hidden behind a flag, not present
/// at all) — nothing here could ever be wired up to play a stream.
struct PrivacyView: View {
    let residents: [FamilyLinkedResident]
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(MeridianColor.success)
                        Text("What you can see")
                            .font(MeridianFont.heading(18))
                        Text("Daily summaries, alert history, and visitor counts for the residents you're linked to. Nothing more.")
                            .font(MeridianFont.body(15))
                            .foregroundStyle(MeridianColor.foregroundMuted)
                    }
                    .padding(.vertical, MeridianSpacing.xs)
                }

                Section {
                    VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(MeridianColor.destructive)
                        Text("What you never see")
                            .font(MeridianFont.heading(18))
                        Text("Live or recorded video. Meridian processes video on-device at the facility and only ever sends alert data and pose information upstream — this app has no video player, because there's nothing for it to play.")
                            .font(MeridianFont.body(15))
                            .foregroundStyle(MeridianColor.foregroundMuted)
                    }
                    .padding(.vertical, MeridianSpacing.xs)
                }

                Section {
                    VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                        Image(systemName: "person.badge.shield.checkmark")
                            .font(.system(size: 32))
                            .foregroundStyle(MeridianColor.primary)
                        Text("Visitor privacy")
                            .font(MeridianFont.heading(18))
                        Text("Unrecognized visitors are logged as anonymous observations, never as identified people. You'll see a count and a time, never a name or photo.")
                            .font(MeridianFont.body(15))
                            .foregroundStyle(MeridianColor.foregroundMuted)
                    }
                    .padding(.vertical, MeridianSpacing.xs)
                }

                Section("Linked residents") {
                    ForEach(residents) { resident in
                        Text(resident.displayName)
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                    .frame(minHeight: MeridianTouchTarget.minSize)
                }
            }
            .navigationTitle("Privacy & account")
        }
    }
}
