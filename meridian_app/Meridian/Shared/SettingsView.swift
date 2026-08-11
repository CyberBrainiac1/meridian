import SwiftUI
import Supabase

/// One settings screen for all three interfaces.
///
/// The three surfaces used to have almost nothing here — Care had a facility
/// name, a role and a sign-out button; Hub had a staff sign-out buried in the
/// help sheet; Family had a sign-out on the privacy tab. That is far too thin
/// for a product people's safety depends on: there was no way to find out that
/// notifications were switched off, no way for a caregiver to mute meal
/// reminders without muting falls, no way for a resident to make the type
/// bigger, and no way for a family member to turn on the SMS escalation the
/// help copy already promised them.
///
/// It is ONE view rather than three because the sections overlap heavily and
/// the ones that do not are role-gated cleanly. It is not one *look*: the
/// style comes from `SettingsStyle.resolve(for:)`, so a resident opening this
/// gets the Hub's 21pt type and 60pt targets and a caregiver gets Care's.
struct SettingsView: View {
    let surface: MeridianSurface
    /// Set when presented as a sheet (Hub, Family). Nil in Care's tab, which
    /// has nothing to close.
    var onClose: (() -> Void)?

    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var readiness = AlertReadinessModel()
    @ObservedObject private var carePreferences = CareNotificationPreferences.shared
    @ObservedObject private var hubTextSize = HubTextSize.shared

    @State private var isConfirmingSignOut = false
    @State private var isChangingPassword = false

    // Family SMS consent, one entry per linked resident.
    @State private var smsPreferences: [String: FamilySmsPreference] = [:]
    @State private var smsDrafts: [String: String] = [:]
    @State private var smsBusyResidentId: String?
    @State private var smsErrors: [String: String] = [:]
    @State private var smsConfirmations: [String: String] = [:]

    private var style: SettingsStyle { .resolve(for: surface) }

    private var isHub: Bool {
        if case .hub = surface { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: style.spacingLG) {
                    if isHub {
                        Text("Settings")
                            .font(style.titleFont)
                            .foregroundStyle(style.foreground)
                            .accessibilityAddTraits(.isHeader)
                    }

                    alertReadinessSection

                    if case .care = surface {
                        careNotificationsSection
                    }
                    if case .hub = surface {
                        hubTextSizeSection
                    }
                    if case .family(let residents) = surface {
                        familySmsSection(residents: residents)
                    }

                    transparencySection
                    accountSection
                    aboutSection

                    if let onClose {
                        closeButton(onClose)
                    }
                }
                .padding(style.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(style.background.ignoresSafeArea())
            .navigationTitle(isHub ? "" : "Settings")
            .toolbar(isHub ? .hidden : .automatic, for: .navigationBar)
            .toolbar {
                if let onClose, !isHub {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done", action: onClose)
                            .font(style.bodyStrongFont)
                            .foregroundStyle(style.primary)
                            .frame(minWidth: style.minTouchTarget, minHeight: style.minTouchTarget)
                    }
                }
            }
        }
        .onAppear {
            readiness.start()
            carePreferences.bindToSignedInUser()
        }
        .onDisappear { readiness.stop() }
        // The readiness answers change in the iOS Settings app, not here, so
        // coming back to the foreground has to re-ask. Otherwise someone who
        // just fixed their notification permission is still told it is broken.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await readiness.refresh() }
        }
        .task { await loadFamilySmsPreferences() }
        .confirmationDialog(
            "Sign out?",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(signOutWarning)
        }
        .sheet(isPresented: $isChangingPassword) {
            ChangePasswordSheet(style: style, onClose: { isChangingPassword = false })
        }
    }

    // MARK: - 1. Alert readiness

    /// First on the screen for every role, above anything anyone came here to
    /// change. See `AlertReadinessModel` for why this exists at all.
    private var alertReadinessSection: some View {
        SettingsCard(
            style: style,
            title: "Alert readiness",
            footer: "This is a check, not a setting. It reports what iOS is currently allowing."
        ) {
            SettingsStatusRow(
                style: style,
                title: "Alerts on this device",
                verdict: readiness.notificationsVerdict,
                detail: readiness.notificationsDetail,
                actionTitle: readiness.needsPermissionRequest
                    ? "Enable Alerts"
                    : readiness.needsSystemSettings ? "Open iOS Settings" : nil,
                action: readiness.needsPermissionRequest
                    ? { Task { await readiness.requestPermission() } }
                    : readiness.needsSystemSettings ? { readiness.openSystemSettings() } : nil
            )

            Divider().overlay(style.border)

            SettingsStatusRow(
                style: style,
                title: "Urgent delivery",
                verdict: readiness.timeSensitiveVerdict,
                detail: readiness.timeSensitiveDetail
            )

            Divider().overlay(style.border)

            SettingsStatusRow(
                style: style,
                title: "Connection",
                verdict: readiness.connectionVerdict,
                detail: readiness.connectionDetail
            )
        }
    }

    // MARK: - 2. Notifications (Care only)

    private var careNotificationsSection: some View {
        SettingsCard(
            style: style,
            title: "Notifications",
            footer: "These apply to this account, on this device. Another caregiver signing in here keeps their own choices."
        ) {
            SettingsLockedRow(
                style: style,
                symbol: CareNotificationTier.falls.symbol,
                title: CareNotificationTier.falls.title,
                detail: CareNotificationTier.falls.detail,
                explanation: "There is no switch for this one. A fall alert nobody hears is the failure this app exists to prevent, so it cannot be turned off from inside the app."
            )

            ForEach(CareNotificationTier.allCases.filter(\.canBeDisabled)) { tier in
                Divider().overlay(style.border)

                SettingsToggleRow(
                    style: style,
                    symbol: tier.symbol,
                    title: tier.title,
                    detail: tier.detail,
                    isOn: Binding(
                        get: { carePreferences.isEnabled(tier) },
                        set: { carePreferences.setEnabled($0, for: tier) }
                    )
                )
            }
        }
    }

    // MARK: - 3. Text size (Hub only)

    private var hubTextSizeSection: some View {
        SettingsCard(
            style: style,
            title: "Text size",
            footer: "This changes the writing everywhere on your screen, not just here."
        ) {
            // Every option is a full-width button rather than a segmented
            // control: a segment on a phone is well under 60pt wide, which is
            // exactly the mis-tap this surface is built to avoid. Choosing is
            // instant and reversible, so there is no confirmation.
            ForEach(HubTextScale.allCases) { scale in
                let isSelected = hubTextSize.scale == scale
                Button {
                    hubTextSize.scale = scale
                } label: {
                    HStack(spacing: style.spacingSM) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(style.iconFont)
                            .foregroundStyle(isSelected ? style.primary : style.foregroundMuted)
                            .accessibilityHidden(true)
                        // Each option is drawn at the size it will produce, so
                        // the choice is legible before it is made. `HubFont`
                        // multiplies by whatever is currently selected, so the
                        // current multiplier is divided back out first —
                        // otherwise picking "Largest" would compound.
                        Text(scale.label)
                            .font(HubFont.bodyStrong(21 * scale.multiplier / HubTextSize.multiplier))
                            .foregroundStyle(style.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: style.spacingXS)
                    }
                    .padding(.horizontal, style.spacingMD)
                    .frame(maxWidth: .infinity, minHeight: style.minTouchTarget, alignment: .leading)
                    .background(isSelected ? style.wash : style.surface)
                    .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.controlRadius)
                            .strokeBorder(isSelected ? style.primary : style.border, lineWidth: style.borderWidth)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(scale.label)
                .accessibilityHint("Sets how big the writing is on every screen")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }

            // Live preview. The whole screen already redraws at the chosen
            // size, but a labelled sample gives the resident something
            // deliberate to read before they walk away from this screen.
            VStack(alignment: .leading, spacing: style.spacingXS) {
                Text("This is how your screen will look")
                    .font(style.bodyStrongFont)
                    .foregroundStyle(style.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Press the button when you would like a caregiver to come to your room.")
                    .font(style.bodyFont)
                    .foregroundStyle(style.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(style.spacingMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.wash)
            .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - 4. Text message alerts (Family only)

    /// The control `FamHelpTopic.privacy` has been promising ("Turn SMS
    /// escalation on or off here at any time") since before it existed.
    ///
    /// Consent is per resident, not per account, because that is how
    /// `family_sms_preferences` is keyed — one active row per
    /// (family_user_id, resident_id) pair.
    @ViewBuilder
    private func familySmsSection(residents: [FamilyLinkedResident]) -> some View {
        SettingsCard(
            style: style,
            title: "Text message alerts",
            footer: "A text is only ever sent when a critical alert has gone unanswered by staff for several minutes. It never replaces the alerts in this app. Message and data rates may apply."
        ) {
            ForEach(Array(residents.enumerated()), id: \.element.id) { index, resident in
                if index > 0 {
                    Divider().overlay(style.border)
                }
                familySmsRows(for: resident)
            }
        }
    }

    @ViewBuilder
    private func familySmsRows(for resident: FamilyLinkedResident) -> some View {
        let residentId = resident.residentId
        let preference = smsPreferences[residentId]
        let isOptedIn = preference?.isOptedIn ?? false
        let isBusy = smsBusyResidentId == residentId

        VStack(alignment: .leading, spacing: style.spacingSM) {
            Text(resident.displayName)
                .font(style.bodyStrongFont)
                .foregroundStyle(style.foreground)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: Binding(
                get: { isOptedIn },
                set: { newValue in
                    Task { await applySmsConsent(residentId: residentId, optIn: newValue) }
                }
            )) {
                HStack(alignment: .top, spacing: style.spacingSM) {
                    Image(systemName: "message.badge.filled.fill")
                        .font(style.iconFont)
                        .foregroundStyle(style.primary)
                        .accessibilityHidden(true)
                    Text("Text me about unanswered critical alerts")
                        .font(style.bodyFont)
                        .foregroundStyle(style.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .tint(style.primary)
            .disabled(isBusy)
            .frame(minHeight: style.minTouchTarget)
            .accessibilityLabel("Text message alerts for \(resident.displayName)")

            if isOptedIn, let phone = preference?.phoneE164 {
                SettingsInfoRow(
                    style: style,
                    symbol: "phone.fill",
                    label: "Texts go to",
                    value: phone
                )
                Text("To use a different number, turn this off and then on again with the new number. Each number is recorded as its own consent, so we never quietly move your alerts somewhere else.")
                    .font(style.captionFont)
                    .foregroundStyle(style.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: style.spacingXS) {
                    Text("Mobile number")
                        .font(style.captionFont)
                        .foregroundStyle(style.foregroundMuted)
                    TextField(
                        "+14155550123",
                        text: Binding(
                            get: { smsDrafts[residentId] ?? "" },
                            set: { smsDrafts[residentId] = $0 }
                        )
                    )
                    .font(style.bodyFont)
                    // Explicit on every text view — see SettingsComponents.
                    .foregroundStyle(style.foreground)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .autocorrectionDisabled()
                    .padding(.horizontal, style.spacingSM)
                    .frame(minHeight: style.minTouchTarget)
                    .background(style.wash)
                    .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.controlRadius)
                            .strokeBorder(style.border, lineWidth: style.borderWidth)
                    )
                    .accessibilityLabel("Mobile number for \(resident.displayName)")
                    .accessibilityHint("Include the plus sign and country code, for example plus one four one five five five five zero one two three")

                    Text("Include the country code, starting with a plus sign.")
                        .font(style.captionFont)
                        .foregroundStyle(style.foregroundMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isBusy {
                HStack(spacing: style.spacingXS) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(style.primary)
                        .accessibilityHidden(true)
                    Text("Saving…")
                        .font(style.captionFont)
                        .foregroundStyle(style.foregroundMuted)
                }
                .frame(minHeight: style.minTouchTarget, alignment: .leading)
            }

            if let message = smsErrors[residentId] {
                SettingsNotice(style: style, tone: .problem, text: message)
            }
            if let message = smsConfirmations[residentId] {
                SettingsNotice(style: style, tone: .success, text: message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 5. What this app can see

    /// Plain-language transparency, and only claims that can be traced to
    /// something in this repository. Anything that could not be verified from
    /// the code was left out rather than softened.
    private var transparencySection: some View {
        SettingsCard(
            style: style,
            title: "What this app can see",
            footer: transparencyFooter
        ) {
            ForEach(Array(transparencyBullets.enumerated()), id: \.offset) { _, bullet in
                SettingsBullet(style: style, symbol: bullet.symbol, text: bullet.text)
            }
        }
    }

    private struct TransparencyBullet {
        let symbol: String
        let text: String
    }

    private var transparencyBullets: [TransparencyBullet] {
        switch surface {
        case .care(_, let facilityName, _):
            return [
                TransparencyBullet(
                    symbol: "building.2.fill",
                    text: "Residents at \(facilityName) only. Every alert list, resident profile, medication schedule and handoff note this app loads is filtered to this facility."
                ),
                TransparencyBullet(
                    symbol: "list.clipboard.fill",
                    text: "For those residents you see full clinical detail: medications and doses, allergies, code status, care notes and shift handoff notes."
                ),
                TransparencyBullet(
                    symbol: "video.slash.fill",
                    text: "No live or recorded video. There is no video player anywhere in this app."
                ),
                TransparencyBullet(
                    symbol: "iphone",
                    text: "Alerts are scheduled by this device from the live feed — they are not push. If this app is fully closed, an alert waits until it is opened again."
                )
            ]

        case .hub(let profile):
            return [
                TransparencyBullet(
                    symbol: "person.fill",
                    text: "This screen only ever shows \(profile.displayName). It never shows another resident."
                ),
                TransparencyBullet(
                    symbol: "pills.fill",
                    text: "Medication reminders show the time only. They never show the name of a medicine or its dose, so this screen is safe to leave face-up."
                ),
                TransparencyBullet(
                    symbol: "checkmark.circle.fill",
                    text: "Tapping a reminder is your own note that you have done it. It is not a medical record — a caregiver still checks."
                ),
                TransparencyBullet(
                    symbol: "message.fill",
                    text: "Messages you send go to the family members linked to this room. They are protected while they travel and where they are stored, but they are not private from Meridian."
                ),
                TransparencyBullet(
                    symbol: "video.slash.fill",
                    text: "No video is shown on this screen."
                )
            ]

        case .family:
            return [
                TransparencyBullet(
                    symbol: "person.text.rectangle.fill",
                    text: "Alerts, visits and daily summaries for the residents you are linked to, and no one else."
                ),
                TransparencyBullet(
                    symbol: "nosign",
                    text: "Never medications, care notes or shift handoff notes. This app does not read any feed that carries them."
                ),
                TransparencyBullet(
                    symbol: "eye.slash.fill",
                    text: "Visitors are counted, never named. The visitor feed has no name and no photo to show."
                ),
                TransparencyBullet(
                    symbol: "lock.fill",
                    text: "Messages are encrypted while they travel and where they are stored, but they are not end-to-end encrypted — Meridian can technically read them."
                ),
                TransparencyBullet(
                    symbol: "video.slash.fill",
                    text: "No live or recorded video. There is no video player anywhere in this app."
                )
            ]
        }
    }

    private var transparencyFooter: String {
        switch surface {
        case .care: return "If something here does not match what you have been told, ask your facility administrator."
        case .hub: return "If any of this is not what you expected, tell a caregiver. You can ask them to stop it at any time."
        case .family: return "Your family member's own consent controls this feed. If they withdraw it, the feed stops."
        }
    }

    // MARK: - 6. Account

    private var accountSection: some View {
        SettingsCard(style: style, title: "Account") {
            SettingsInfoRow(
                style: style,
                symbol: "person.crop.circle",
                label: "Signed in as",
                value: signedInName
            )

            if let facilityName = resolvedFacilityName {
                Divider().overlay(style.border)
                SettingsInfoRow(
                    style: style,
                    symbol: "building.2",
                    label: "Facility",
                    value: facilityName
                )
            }

            Divider().overlay(style.border)

            SettingsInfoRow(
                style: style,
                symbol: "person.badge.key",
                label: "Role",
                value: roleName
            )

            Divider().overlay(style.border)

            SettingsActionRow(
                style: style,
                symbol: "key.fill",
                title: "Change password",
                detail: "At least 6 characters, typed twice."
            ) {
                isChangingPassword = true
            }

            Divider().overlay(style.border)

            SettingsActionRow(
                style: style,
                symbol: "rectangle.portrait.and.arrow.right",
                title: "Sign out",
                detail: signOutWarning,
                isDestructive: true
            ) {
                isConfirmingSignOut = true
            }
        }
    }

    private var signOutWarning: String {
        switch surface {
        case .care: return "This device stops receiving alerts for your residents until someone signs in again."
        case .hub: return "This screen stops showing this resident's reminders and help buttons until someone signs in again."
        case .family: return "You stop receiving updates in this app until you sign in again."
        }
    }

    /// Nobody in this product types an email address — `AuthViewModel` builds
    /// one from the name and facility (`lin_nakamura@meridian-demo.…`). This
    /// unwinds that so the row shows the name they actually signed in with,
    /// rather than a synthetic address that looks like a bug.
    private var signedInName: String {
        if case .hub(let profile) = surface { return profile.displayName }
        guard let email = SupabaseManager.client.auth.currentUser?.email,
              let local = email.split(separator: "@").first, !local.isEmpty
        else {
            return "Signed in"
        }
        return local
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Family accounts carry no facility identifier anywhere this app can
    /// read, so that row is omitted for them rather than filled with a guess.
    private var resolvedFacilityName: String? {
        switch surface {
        case .care(_, let facilityName, _):
            return facilityName
        case .hub(let profile):
            return auth.facilities.first { $0.id == profile.facilityId }?.displayName ?? profile.facilityId
        case .family:
            return nil
        }
    }

    private var roleName: String {
        switch surface {
        case .care(_, _, let role): return role.rawValue.capitalized
        case .hub: return "Resident"
        case .family: return "Family member"
        }
    }

    // MARK: - 7. About

    private var aboutSection: some View {
        SettingsCard(style: style, title: "About") {
            SettingsInfoRow(
                style: style,
                symbol: "app.badge",
                label: "Version",
                value: Self.versionString
            )

            if let facilityName = resolvedFacilityName {
                Divider().overlay(style.border)
                Text("Meridian at \(facilityName).")
                    .font(style.bodyFont)
                    .foregroundStyle(style.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            } else if case .family(let residents) = surface, let first = residents.first {
                Divider().overlay(style.border)
                Text(
                    residents.count == 1
                        ? "Meridian, linked to \(first.displayName)."
                        : "Meridian, linked to \(residents.count) residents."
                )
                .font(style.bodyFont)
                .foregroundStyle(style.foreground)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Real build metadata only. There is deliberately no support phone number
    /// here — inventing one would send someone in an emergency to a dead line.
    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    // MARK: - Close

    private func closeButton(_ close: @escaping () -> Void) -> some View {
        Button(action: close) {
            HStack(spacing: style.spacingSM) {
                Image(systemName: "checkmark.circle.fill")
                    .font(style.iconFont)
                    .accessibilityHidden(true)
                Text("Close settings")
                    .font(style.bodyStrongFont)
            }
            .frame(maxWidth: .infinity, minHeight: style.minTouchTarget)
            .padding(style.spacingSM)
            .foregroundStyle(style.primary)
            .background(style.surface)
            .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: style.controlRadius)
                    .strokeBorder(style.primary, lineWidth: style.borderWidth + 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close settings")
        .padding(.top, style.minSpacing)
    }

    // MARK: - Family SMS actions

    private func loadFamilySmsPreferences() async {
        guard case .family = surface else { return }
        smsPreferences = await FamilySmsConsentService.loadActive()
    }

    private func applySmsConsent(residentId: String, optIn: Bool) async {
        smsErrors[residentId] = nil
        smsConfirmations[residentId] = nil

        var phone: String?
        if optIn {
            // Validated locally first so a mistyped number comes back as a
            // sentence naming the problem, rather than as the RPC's
            // `invalid_e164_phone_number`.
            switch FamilySmsConsentService.validate(smsDrafts[residentId] ?? "") {
            case .failure(let error):
                smsErrors[residentId] = error.errorDescription
                return
            case .success(let normalized):
                phone = normalized
                smsDrafts[residentId] = normalized
            }
        } else {
            phone = smsPreferences[residentId]?.phoneE164
        }

        smsBusyResidentId = residentId
        let result = await FamilySmsConsentService.setConsent(
            residentId: residentId,
            phoneE164: phone,
            optIn: optIn
        )
        smsBusyResidentId = nil

        switch result {
        case .success:
            smsPreferences = await FamilySmsConsentService.loadActive()
            smsConfirmations[residentId] = optIn
                ? "Text alerts are on. Unanswered critical alerts will be sent to \(phone ?? "your number")."
                : "Text alerts are off. You will still see every alert in this app."
        case .failure(let error):
            smsErrors[residentId] = error.errorDescription
            // Re-read either way: a revoke that raced another device leaves
            // the toggle showing a state the server does not agree with.
            smsPreferences = await FamilySmsConsentService.loadActive()
        }
    }
}

// MARK: - Change password

/// Password change, gated on a confirm field and a 6-character floor (the
/// minimum Supabase Auth itself enforces). Deliberately its own sheet: it is
/// the one thing on this screen that can lock somebody out of a device they
/// may need in an emergency, so it does not sit one stray tap away from the
/// rows above it.
struct ChangePasswordSheet: View {
    let style: SettingsStyle
    let onClose: () -> Void

    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    private static let minimumLength = 6

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: style.spacingMD) {
                    Text("Choose a new password for this account. You stay signed in on this device.")
                        .font(style.bodyFont)
                        .foregroundStyle(style.foreground)
                        .fixedSize(horizontal: false, vertical: true)

                    field(
                        label: "New password",
                        text: $newPassword,
                        hint: "At least \(Self.minimumLength) characters"
                    )
                    field(
                        label: "Type it again",
                        text: $confirmation,
                        hint: "Must match the password above"
                    )

                    if let errorMessage {
                        SettingsNotice(style: style, tone: .problem, text: errorMessage)
                    }
                    if didSucceed {
                        SettingsNotice(
                            style: style,
                            tone: .success,
                            text: "Password changed. Use the new one the next time you sign in."
                        )
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: style.spacingXS) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(style.onPrimary)
                                    .accessibilityHidden(true)
                            } else {
                                Image(systemName: "key.fill")
                                    .font(style.iconFont)
                                    .accessibilityHidden(true)
                            }
                            Text(isSubmitting ? "Saving…" : "Save new password")
                                .font(style.bodyStrongFont)
                        }
                        .frame(maxWidth: .infinity, minHeight: style.minTouchTarget)
                        .padding(style.spacingSM)
                        .foregroundStyle(style.onPrimary)
                        .background(style.primary)
                        .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                    .accessibilityLabel("Save new password")

                    Button(action: onClose) {
                        Text(didSucceed ? "Close" : "Cancel")
                            .font(style.bodyStrongFont)
                            .foregroundStyle(style.primary)
                            .frame(maxWidth: .infinity, minHeight: style.minTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(didSucceed ? "Close" : "Cancel")
                }
                .padding(style.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(style.background.ignoresSafeArea())
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func field(label: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: style.spacingXS) {
            Text(label)
                .font(style.captionFont)
                .foregroundStyle(style.foregroundMuted)
            SecureField(label, text: text)
                .font(style.bodyFont)
                .foregroundStyle(style.foreground)
                .textContentType(.newPassword)
                .padding(.horizontal, style.spacingSM)
                .frame(minHeight: style.minTouchTarget)
                .background(style.wash)
                .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: style.controlRadius)
                        .strokeBorder(style.border, lineWidth: style.borderWidth)
                )
                .accessibilityLabel(label)
                .accessibilityHint(hint)
            Text(hint)
                .font(style.captionFont)
                .foregroundStyle(style.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func submit() async {
        errorMessage = nil
        didSucceed = false

        guard newPassword.count >= Self.minimumLength else {
            errorMessage = "That password is too short. Use at least \(Self.minimumLength) characters."
            return
        }
        guard newPassword == confirmation else {
            errorMessage = "The two passwords don't match. Type the same one in both boxes."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await SupabaseManager.client.auth.update(
                user: UserAttributes(password: newPassword)
            )
            didSucceed = true
            newPassword = ""
            confirmation = ""
        } catch {
            errorMessage = "Couldn't change the password just now. Check the connection and try again."
        }
    }
}
