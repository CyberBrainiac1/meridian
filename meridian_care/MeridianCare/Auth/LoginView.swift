import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    let errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: MeridianSpacing.lg) {
                VStack(spacing: MeridianSpacing.unit) {
                    Text("Meridian Care")
                        .font(MeridianFont.heading(28))
                        .foregroundStyle(MeridianColor.foreground)
                    Text("Sign in to see live alerts for your facility.")
                        .font(MeridianFont.body(15))
                        .foregroundStyle(MeridianColor.foregroundMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, MeridianSpacing.xl)

                VStack(spacing: MeridianSpacing.sm) {
                    TextField("Email", text: $auth.email)
                        .foregroundStyle(MeridianColor.foreground)
                        .tint(MeridianColor.primaryAlt)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .padding()
                        .frame(minHeight: MeridianTouchTarget.minSize)
                        .background(MeridianColor.surface, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: MeridianRadius.control).stroke(MeridianColor.border))
                        .accessibilityLabel("Email")

                    SecureField("Password", text: $auth.password)
                        .foregroundStyle(MeridianColor.foreground)
                        .tint(MeridianColor.primaryAlt)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await auth.signIn() } }
                        .padding()
                        .frame(minHeight: MeridianTouchTarget.minSize)
                        .background(MeridianColor.surface, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: MeridianRadius.control).stroke(MeridianColor.border))
                        .accessibilityLabel("Password")

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(MeridianColor.destructive)
                            .accessibilityAddTraits(.isStaticText)
                    }

                    if !SupabaseConfig.isConfigured {
                        Text("This build has no Supabase project configured yet (Config/Secrets.xcconfig is empty). See frontendguytodo.md.")
                            .font(.footnote)
                            .foregroundStyle(MeridianColor.warning)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await auth.signIn() }
                    } label: {
                        if auth.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign in").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(MeridianButtonStyle(kind: .primary))
                    .disabled(auth.isSubmitting)
                    .padding(.top, MeridianSpacing.xs)
                }
                .padding(MeridianSpacing.lg)
                .background(MeridianColor.surface, in: RoundedRectangle(cornerRadius: MeridianRadius.card))
            }
            .padding(MeridianSpacing.lg)
        }
        .background(MeridianColor.background)
        .scrollDismissesKeyboard(.interactively)
    }
}
