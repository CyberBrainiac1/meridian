import SwiftUI

// Building blocks for `SettingsView`. Every one of them takes a
// `SettingsStyle` rather than reaching for a token module, so the same row
// renders at Care's 16pt/44pt and the Hub's 21pt/60pt without a second
// implementation. Rules held here rather than repeated at each call site:
// every text view sets an explicit `.foregroundStyle` (unstyled text turns
// white in Dark Mode and vanishes against these fixed light palettes — a bug
// this codebase has shipped twice), every icon is paired with visible text,
// and every tappable row clears the surface's own minimum touch target.

/// A titled card. The title sits outside the card so it reads as a heading
/// rather than as the card's first row.
struct SettingsCard<Content: View>: View {
    let style: SettingsStyle
    var title: String?
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacingXS) {
            if let title {
                Text(title)
                    .font(style.sectionFont)
                    .foregroundStyle(style.foregroundMuted)
                    .textCase(.none)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, style.spacingXS)
            }

            VStack(alignment: .leading, spacing: style.spacingSM) {
                content()
            }
            .padding(style.spacingMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.surface)
            .clipShape(RoundedRectangle(cornerRadius: style.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: style.cardRadius)
                    .strokeBorder(style.border, lineWidth: style.borderWidth)
            )

            if let footer {
                Text(footer)
                    .font(style.captionFont)
                    .foregroundStyle(style.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, style.spacingXS)
            }
        }
    }
}

/// A pass/attention line for the readiness check. The state is carried by an
/// icon AND a word — never by colour alone, which is unreadable to roughly one
/// man in twelve and invisible to anyone glancing at a phone in a corridor.
struct SettingsStatusRow: View {
    let style: SettingsStyle
    let title: String
    let verdict: AlertReadinessModel.Verdict
    let detail: String
    var actionTitle: String?
    var action: (() -> Void)?

    private var accent: Color {
        switch verdict {
        case .pass: return style.success
        case .attention: return style.warning
        case .unknown: return style.foregroundMuted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacingXS) {
            HStack(alignment: .firstTextBaseline, spacing: style.spacingSM) {
                Image(systemName: verdict.symbol)
                    .font(style.iconFont)
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)

                Text(title)
                    .font(style.bodyStrongFont)
                    .foregroundStyle(style.foreground)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: style.spacingXS)

                Text(verdict.word)
                    .font(style.captionFont)
                    .foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(detail)
                .font(style.captionFont)
                .foregroundStyle(style.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: style.spacingXS) {
                        Image(systemName: "gear")
                            .font(style.iconFont)
                            .accessibilityHidden(true)
                        Text(actionTitle)
                            .font(style.bodyStrongFont)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, style.spacingMD)
                    .frame(minHeight: style.minTouchTarget)
                    .foregroundStyle(style.onPrimary)
                    .background(style.primary)
                    .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
                }
                .buttonStyle(.plain)
                .padding(.top, style.spacingXS)
                .accessibilityLabel(actionTitle)
                .accessibilityHint("Opens the iOS Settings app so notifications can be turned on for Meridian")
            }
        }
        .frame(minHeight: style.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: action == nil ? .combine : .contain)
        .accessibilityLabel(action == nil ? "\(title). \(verdict.word). \(detail)" : "")
    }
}

/// Label on the left, value on the right. Read-only.
struct SettingsInfoRow: View {
    let style: SettingsStyle
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: style.spacingSM) {
            Image(systemName: symbol)
                .font(style.iconFont)
                .foregroundStyle(style.primary)
                .accessibilityHidden(true)

            Text(label)
                .font(style.bodyFont)
                .foregroundStyle(style.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: style.spacingSM)

            Text(value)
                .font(style.bodyStrongFont)
                .foregroundStyle(style.foreground)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: style.minTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// A switchable notification tier.
struct SettingsToggleRow: View {
    let style: SettingsStyle
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: style.spacingSM) {
                Image(systemName: symbol)
                    .font(style.iconFont)
                    .foregroundStyle(style.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: style.spacingXS / 2) {
                    Text(title)
                        .font(style.bodyStrongFont)
                        .foregroundStyle(style.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(style.captionFont)
                        .foregroundStyle(style.foregroundMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .tint(style.primary)
        .frame(minHeight: style.minTouchTarget)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

/// A tier that is deliberately not switchable. Rendered as a statement with a
/// lock rather than as a disabled `Toggle`: a greyed-out switch reads as
/// broken and sends people hunting for the working one.
struct SettingsLockedRow: View {
    let style: SettingsStyle
    let symbol: String
    let title: String
    let detail: String
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacingXS) {
            HStack(alignment: .top, spacing: style.spacingSM) {
                Image(systemName: symbol)
                    .font(style.iconFont)
                    .foregroundStyle(style.destructive)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: style.spacingXS / 2) {
                    Text(title)
                        .font(style.bodyStrongFont)
                        .foregroundStyle(style.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(style.captionFont)
                        .foregroundStyle(style.foregroundMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: style.spacingXS)

                HStack(spacing: style.spacingXS / 2) {
                    Image(systemName: "lock.fill")
                        .font(style.captionFont)
                        .accessibilityHidden(true)
                    Text("Always on")
                        .font(style.captionFont)
                }
                .foregroundStyle(style.destructive)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text(explanation)
                .font(style.captionFont)
                .foregroundStyle(style.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(style.spacingSM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(style.wash)
                .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
        }
        .frame(minHeight: style.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). Always on and cannot be turned off. \(detail) \(explanation)")
    }
}

/// A tappable row that opens something else.
struct SettingsActionRow: View {
    let style: SettingsStyle
    let symbol: String
    let title: String
    var detail: String?
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: style.spacingSM) {
                Image(systemName: symbol)
                    .font(style.iconFont)
                    .foregroundStyle(isDestructive ? style.destructive : style.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: style.spacingXS / 2) {
                    Text(title)
                        .font(style.bodyStrongFont)
                        .foregroundStyle(isDestructive ? style.destructive : style.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(style.captionFont)
                            .foregroundStyle(style.foregroundMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: style.spacingXS)

                Image(systemName: "chevron.right")
                    .font(style.captionFont)
                    .foregroundStyle(style.foregroundMuted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: style.minTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail ?? "")
    }
}

/// One plain-language transparency line. The icon is decorative; the sentence
/// carries everything.
struct SettingsBullet: View {
    let style: SettingsStyle
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: style.spacingSM) {
            Image(systemName: symbol)
                .font(style.iconFont)
                .foregroundStyle(style.primary)
                .accessibilityHidden(true)
            Text(text)
                .font(style.bodyFont)
                .foregroundStyle(style.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

/// Persistent feedback. Nothing on this screen auto-dismisses — a message that
/// disappears on a timer is a message someone who reads slowly never got.
struct SettingsNotice: View {
    enum Tone { case success, problem }

    let style: SettingsStyle
    let tone: Tone
    let text: String

    private var accent: Color {
        tone == .success ? style.success : style.destructive
    }

    private var symbol: String {
        tone == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    var body: some View {
        HStack(alignment: .top, spacing: style.spacingSM) {
            Image(systemName: symbol)
                .font(style.iconFont)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text(text)
                .font(style.captionFont)
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(style.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.surface)
        .clipShape(RoundedRectangle(cornerRadius: style.controlRadius))
        .overlay(
            RoundedRectangle(cornerRadius: style.controlRadius)
                .strokeBorder(accent, lineWidth: style.borderWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
