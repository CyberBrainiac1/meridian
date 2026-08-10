import SwiftUI

/// Realistically a caregiver uses this screen once, while setting the phone up
/// in the resident's room. But the resident may well be sitting right there,
/// and may land here again months later if the session ever drops — so it is
/// sized and worded like the rest of the app: large type, one instruction at a
/// time, and nothing that reads as an error or a lockout.
struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    let errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeridianTouchTarget.minSpacing) {
                header

                fieldBlock(
                    label: "Email",
                    field: {
                        TextField("", text: $auth.email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                )

                fieldBlock(
                    label: "Password",
                    field: {
                        SecureField("", text: $auth.password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await auth.signIn() } }
                    }
                )

                // Stays on screen until the next attempt. Nothing on this app
                // fades out on its own — a message that vanishes is a message
                // the reader never had a chance to finish.
                if let errorMessage {
                    Text(errorMessage)
                        .font(MeridianFont.bodyStrong())
                        .foregroundStyle(MeridianColor.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isStaticText)
                }

                if !SupabaseConfig.isConfigured {
                    Text("This copy of Meridian has no Supabase project set up yet, so signing in won't work. A staff member needs to finish configuring the app.")
                        .font(MeridianFont.body())
                        .foregroundStyle(MeridianColor.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                connectButton

                Text("A staff member sets this up once. If you're not sure what to enter, ask someone at the front desk — nothing is wrong with your phone.")
                    .font(MeridianFont.body(18))
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(MeridianSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MeridianColor.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
            Image(systemName: "house.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(MeridianColor.primary)
            Text("Meridian")
                .font(MeridianFont.title())
                .foregroundStyle(MeridianColor.foreground)
            Text("Set up this phone for the room.")
                .font(MeridianFont.body())
                .foregroundStyle(MeridianColor.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, MeridianSpacing.xl)
        .padding(.bottom, MeridianSpacing.xs)
    }

    /// Label above the box, never a placeholder inside it: placeholder text
    /// disappears the moment typing starts, which is exactly when someone
    /// looking away and back needs to know which box they're in.
    private func fieldBlock<F: View>(label: String, @ViewBuilder field: () -> F) -> some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
            Text(label)
                .font(MeridianFont.bodyStrong())
                .foregroundStyle(MeridianColor.foreground)

            field()
                // Set explicitly. Inherited/default styling left the text
                // invisible in the other two apps; do not rely on it here.
                .font(MeridianFont.body())
                .foregroundStyle(MeridianColor.foreground)
                .tint(MeridianColor.primary)
                .padding(.horizontal, MeridianSpacing.md)
                .frame(minHeight: MeridianTouchTarget.minSize)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MeridianColor.surface, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: MeridianRadius.control)
                        .stroke(MeridianColor.border, lineWidth: 2)
                )
                .accessibilityLabel(label)
        }
    }

    private var connectButton: some View {
        Button {
            focusedField = nil
            Task { await auth.signIn() }
        } label: {
            Group {
                if auth.isSubmitting {
                    HStack(spacing: MeridianSpacing.sm) {
                        ProgressView().tint(MeridianColor.onPrimary)
                        Text("Connecting…")
                    }
                } else {
                    Text("Connect this device")
                }
            }
            .font(MeridianFont.action())
            .foregroundStyle(MeridianColor.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: MeridianTouchTarget.primaryHeight)
            .padding(.horizontal, MeridianSpacing.md)
            .background(
                (auth.isSubmitting ? MeridianColor.primaryHover : MeridianColor.primary),
                in: RoundedRectangle(cornerRadius: MeridianRadius.control)
            )
        }
        .buttonStyle(.plain)
        .disabled(auth.isSubmitting)
        .accessibilityLabel(auth.isSubmitting ? "Connecting" : "Connect this device")
        .padding(.top, MeridianSpacing.xs)
    }
}
