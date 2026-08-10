import SwiftUI

/// Step one of sign-in: which building.
///
/// This exists so nobody has to type an email. Picking the facility supplies
/// the half of the identity that is impossible to remember, leaving only a
/// name and a password — both of which a person actually knows about
/// themselves.
struct FacilityPickerView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuthStyle.gap) {
                VStack(alignment: .leading, spacing: AuthStyle.tightGap) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(AuthStyle.primary)
                    Text("Meridian")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(AuthStyle.foreground)
                    Text("Choose where you are.")
                        .font(.system(size: 20))
                        .foregroundStyle(AuthStyle.foregroundMuted)
                }
                .padding(.top, AuthStyle.gap)

                if auth.isLoadingFacilities && auth.facilities.isEmpty {
                    HStack(spacing: AuthStyle.tightGap) {
                        ProgressView()
                        Text("Loading facilities…")
                            .font(.system(size: 18))
                            .foregroundStyle(AuthStyle.foregroundMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AuthStyle.gap)
                }

                ForEach(auth.facilities) { facility in
                    FacilityCard(facility: facility) { auth.choose(facility) }
                }

                if let errorMessage = auth.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AuthStyle.destructive)

                    Button("Try again") {
                        Task { await auth.loadFacilities() }
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AuthStyle.primary)
                    .frame(minHeight: AuthStyle.minTarget)
                }
            }
            .padding(AuthStyle.gap)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AuthStyle.background.ignoresSafeArea())
    }
}

private struct FacilityCard: View {
    let facility: MeridianFacility
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuthStyle.tightGap) {
                Image(systemName: facility.hasAccounts ? "building.2.fill" : "building.2")
                    .font(.system(size: 28))
                    .foregroundStyle(facility.hasAccounts ? AuthStyle.primary : AuthStyle.foregroundMuted)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(facility.displayName)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(facility.hasAccounts ? AuthStyle.foreground : AuthStyle.foregroundMuted)
                        .multilineTextAlignment(.leading)
                    // Stated rather than merely greyed out: a disabled card
                    // with no explanation reads as a broken app.
                    if !facility.hasAccounts {
                        Text("No accounts here yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AuthStyle.foregroundMuted)
                    }
                }

                Spacer(minLength: 0)

                if facility.hasAccounts {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AuthStyle.foregroundMuted)
                }
            }
            .padding(AuthStyle.gap)
            .frame(maxWidth: .infinity, minHeight: AuthStyle.minTarget, alignment: .leading)
            .background(AuthStyle.surface, in: RoundedRectangle(cornerRadius: AuthStyle.radius))
            .overlay(
                RoundedRectangle(cornerRadius: AuthStyle.radius)
                    .stroke(facility.hasAccounts ? AuthStyle.primary : AuthStyle.border, lineWidth: 2)
            )
        }
        .disabled(!facility.hasAccounts)
        .accessibilityLabel(
            facility.hasAccounts
                ? facility.displayName
                : "\(facility.displayName), no accounts here yet"
        )
    }
}
