import SwiftUI

/// Step two: name and password.
///
/// The name is `First_Last` because that is what the account was created as,
/// and saying so on screen is cheaper than any amount of validation copy.
/// `AuthViewModel.email(for:facilityId:)` forgives case and spaces, so the
/// hint is guidance rather than a rule someone can fail.
struct SignInView: View {
    let facility: MeridianFacility
    @EnvironmentObject var auth: AuthViewModel
    @FocusState private var focused: Field?

    private enum Field { case name, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuthStyle.gap) {
                Button {
                    auth.backToFacilities()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Change facility")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AuthStyle.primary)
                }
                .frame(minHeight: AuthStyle.minTarget)
                .accessibilityLabel("Back to facility list")

                VStack(alignment: .leading, spacing: AuthStyle.tightGap) {
                    Text(facility.displayName)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(AuthStyle.foreground)
                    Text("Sign in with your name.")
                        .font(.system(size: 19))
                        .foregroundStyle(AuthStyle.foregroundMuted)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AuthStyle.foreground)
                    TextField("First_Last", text: $auth.name)
                        .font(.system(size: 20))
                        // Set explicitly: without it, iOS Dark Mode renders
                        // this white on a light field and the text is
                        // invisible as you type.
                        .foregroundStyle(AuthStyle.foreground)
                        .tint(AuthStyle.primary)
                        .textContentType(.username)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .password }
                        .padding()
                        .frame(minHeight: AuthStyle.minTarget)
                        .background(AuthStyle.surface, in: RoundedRectangle(cornerRadius: AuthStyle.radius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AuthStyle.radius)
                                .stroke(AuthStyle.border, lineWidth: 2)
                        )
                    // Deliberately NOT a sample name. An example here is a
                    // real, working username at this facility — putting one
                    // on the sign-in screen hands a stranger half of a
                    // credential, and on a resident's device it names an
                    // actual person to anyone who picks the phone up.
                    // Describe the shape instead.
                    Text("Your first and last name, joined by an underscore.")
                        .font(.system(size: 15))
                        .foregroundStyle(AuthStyle.foregroundMuted)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AuthStyle.foreground)
                    SecureField("Password", text: $auth.password)
                        .font(.system(size: 20))
                        .foregroundStyle(AuthStyle.foreground)
                        .tint(AuthStyle.primary)
                        .textContentType(.password)
                        .focused($focused, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await auth.signIn() } }
                        .padding()
                        .frame(minHeight: AuthStyle.minTarget)
                        .background(AuthStyle.surface, in: RoundedRectangle(cornerRadius: AuthStyle.radius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AuthStyle.radius)
                                .stroke(AuthStyle.border, lineWidth: 2)
                        )
                }

                // Persistent: it stays until the next attempt rather than
                // disappearing while someone is still reading it.
                if let errorMessage = auth.errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMessage)
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AuthStyle.destructive)
                }

                Button {
                    focused = nil
                    Task { await auth.signIn() }
                } label: {
                    Group {
                        if auth.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign in")
                        }
                    }
                    .font(.system(size: 21, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: AuthStyle.minTarget)
                    .foregroundStyle(.white)
                    .background(AuthStyle.primary, in: RoundedRectangle(cornerRadius: AuthStyle.radius))
                }
                .disabled(auth.isSubmitting)

                Spacer(minLength: 0)
            }
            .padding(AuthStyle.gap)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AuthStyle.background.ignoresSafeArea())
        .onAppear { focused = .name }
    }
}

/// Sign-in has its own small style set on purpose. It is the one screen shown
/// before we know who the user is, so it cannot borrow the caregiver, resident
/// or family design system — those differ from each other precisely because
/// they serve different people, and picking one here would mean showing an
/// 88-year-old resident a caregiver-sized screen.
enum AuthStyle {
    static let primary = Color(red: 0x07 / 255, green: 0x59 / 255, blue: 0x85 / 255)
    static let foreground = Color(red: 0x0C / 255, green: 0x4A / 255, blue: 0x6E / 255)
    static let foregroundMuted = Color(red: 0x0F / 255, green: 0x3D / 255, blue: 0x54 / 255)
    static let background = Color(red: 0xEC / 255, green: 0xFE / 255, blue: 0xFF / 255)
    static let surface = Color.white
    static let border = Color(red: 0x7D / 255, green: 0xD3 / 255, blue: 0xFC / 255)
    static let destructive = Color(red: 0x99 / 255, green: 0x1B / 255, blue: 0x1B / 255)

    /// Sized for the least confident user who could plausibly reach this
    /// screen — a resident setting up their own phone.
    static let minTarget: CGFloat = 56
    static let gap: CGFloat = 24
    static let tightGap: CGFloat = 12
    static let radius: CGFloat = 16
}
