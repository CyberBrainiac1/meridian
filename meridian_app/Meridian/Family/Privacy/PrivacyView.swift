import SwiftUI

/// Explicit privacy controls — makes the "families never see live video"
/// boundary visible and legible. There is deliberately no video player
/// component anywhere in this app (not hidden behind a flag, not present
/// at all) — nothing here could ever be wired up to play a stream.
struct PrivacyView: View {
    let residents: [FamilyLinkedResident]
    @EnvironmentObject var auth: AuthViewModel
    @State private var isShowingHelp = false
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: FamSpacing.sm) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(FamColor.success)
                        Text("What you can see")
                            .font(FamFont.heading(18))
                        Text("Daily summaries, alert history, and visitor counts for the residents you're linked to. Nothing more.")
                            .font(FamFont.body(15))
                            .foregroundStyle(FamColor.foregroundMuted)
                    }
                    .padding(.vertical, FamSpacing.xs)
                }

                Section {
                    VStack(alignment: .leading, spacing: FamSpacing.sm) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(FamColor.destructive)
                        Text("What you never see")
                            .font(FamFont.heading(18))
                        Text("Live or recorded video. Meridian processes video on-device at the facility and only ever sends alert data and pose information upstream — this app has no video player, because there's nothing for it to play.")
                            .font(FamFont.body(15))
                            .foregroundStyle(FamColor.foregroundMuted)
                    }
                    .padding(.vertical, FamSpacing.xs)
                }

                Section {
                    VStack(alignment: .leading, spacing: FamSpacing.sm) {
                        Image(systemName: "person.badge.shield.checkmark")
                            .font(.system(size: 32))
                            .foregroundStyle(FamColor.primary)
                        Text("Visitor privacy")
                            .font(FamFont.heading(18))
                        Text("Unrecognized visitors are logged as anonymous observations, never as identified people. You'll see a count and a time, never a name or photo.")
                            .font(FamFont.body(15))
                            .foregroundStyle(FamColor.foregroundMuted)
                    }
                    .padding(.vertical, FamSpacing.xs)
                }

                Section("Linked residents") {
                    ForEach(residents) { resident in
                        Text(resident.displayName)
                    }
                }

                // Settings is reached from here rather than from a sixth tab.
                // The tab bar already holds five items, which is where iOS
                // starts collapsing the rest into a "More" list — a settings
                // screen buried one level inside an auto-generated list is
                // worse than one row on the tab that is already titled
                // "Privacy & account" and already carries sign-out. Everything
                // in Settings (alert readiness, SMS consent, the account rows)
                // is the same subject as this tab.
                Section {
                    Button {
                        isShowingSettings = true
                    } label: {
                        HStack(spacing: FamSpacing.sm) {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(FamColor.primary)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Settings")
                                    .font(FamFont.bodyMedium(16))
                                    .foregroundStyle(FamColor.foreground)
                                Text("Alert checks, text message alerts, password")
                                    .font(FamFont.body(13))
                                    .foregroundStyle(FamColor.foregroundMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: FamSpacing.xs)
                            Image(systemName: "chevron.right")
                                .font(FamFont.body(13))
                                .foregroundStyle(FamColor.foregroundMuted)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: FamTouchTarget.minSize)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Alert checks, text message alerts, and your password")
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                    .frame(minHeight: FamTouchTarget.minSize)
                }
            }
            .navigationTitle("Privacy & account")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .frame(minWidth: FamTouchTarget.minSize, minHeight: FamTouchTarget.minSize)
                    }
                    .accessibilityLabel("Help")
                }
            }
            .sheet(isPresented: $isShowingHelp) {
                FamHelpTourView(topic: .privacy)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(
                    surface: .family(residents: residents),
                    onClose: { isShowingSettings = false }
                )
            }
        }
    }
}
