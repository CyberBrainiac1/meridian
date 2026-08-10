import SwiftUI

/// The resident's Hub surface, ported from the retired web app's
/// `components/hub-surface.tsx`.
///
/// Layout rules that are not negotiable on this screen: every control clears
/// `MeridianTouchTarget.minSize` with `minSpacing` of clear space around it,
/// every icon is paired with visible text (and every control carries an
/// `accessibilityLabel`), nothing is reachable only by swipe or long-press,
/// and nothing on screen dismisses itself.
struct HubSurfaceView: View {
    let profile: HubProfile

    @StateObject private var model = HubSurfaceViewModel()

    init(profile: HubProfile) {
        self.profile = profile
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeridianTouchTarget.minSpacing) {
                header

                if !model.online {
                    connectionBanner
                }

                if let notice = model.notice {
                    HubNoticeBanner(notice: notice)
                }

                if let request = model.shownRequest {
                    HubStatusCard(request: request)
                }

                actions

                if !model.reminderRows.isEmpty {
                    HubRemindersCard(
                        rows: model.reminderRows,
                        nextID: model.nextReminderID,
                        onToggle: { row in Task { await model.toggle(row) } }
                    )
                }

                if let prompt = model.pendingPrompt {
                    HubVisitorCard(
                        prompt: prompt,
                        secondsLeft: model.secondsRemaining(for: prompt),
                        busy: model.busyKind == HubBusyKind.visitor,
                        // Any other action in flight locks the answer buttons —
                        // but never the other way round.
                        locked: model.busyKind != nil && model.busyKind != HubBusyKind.visitor,
                        onAnswer: { response in
                            Task { await model.respondToVisitor(prompt, response: response) }
                        }
                    )
                }
            }
            .padding(.horizontal, MeridianSpacing.lg)
            .padding(.top, MeridianSpacing.lg)
            .padding(.bottom, MeridianSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MeridianColor.background.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        // Announced rather than merely drawn: a resident using VoiceOver has to
        // be told the request landed, not just shown it.
        .onChange(of: model.notice) { _, newValue in
            guard let newValue else { return }
            AccessibilityNotification.Announcement(newValue.text).post()
        }
        .onChange(of: model.shownRequest?.status) { _, _ in
            guard let request = model.shownRequest else { return }
            AccessibilityNotification.Announcement(HubCopy.statusHeading(for: request)).post()
        }
        // The web panel expanded in place so it could never sit on top of
        // Emergency help. A sheet is the phone equivalent: closed, it takes up
        // no space and covers nothing.
        .sheet(isPresented: $model.isHelpOpen) {
            HelpPanelView(onClose: { model.isHelpOpen = false })
        }
        // Same sheet pattern as Help: closed, it takes up no space; open, a
        // resident with a tremor still has an explicit Close button inside it
        // rather than only a drag-to-dismiss gesture.
        .sheet(isPresented: $model.isMessagesOpen) {
            MessageThreadView(profile: profile)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: MeridianTouchTarget.minSpacing) {
            VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                Text("MeridianHub · Room \(profile.roomId)")
                    .font(MeridianFont.bodyStrong())
                    .foregroundStyle(MeridianColor.foregroundMuted)
                Text("Hello, \(profile.displayName)")
                    .font(MeridianFont.title())
                    .foregroundStyle(MeridianColor.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Choose what you need. Your care team is here to help.")
                    .font(MeridianFont.body())
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // A plain button that can be opened as many times as they like —
            // deliberately not a one-time walkthrough, which would assume the
            // resident remembers it.
            Button {
                model.isHelpOpen = true
            } label: {
                HStack(spacing: MeridianSpacing.sm) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(MeridianFont.heading(26))
                        .accessibilityHidden(true)
                    Text("What can I do here?")
                        .font(MeridianFont.bodyStrong(24))
                }
                .padding(.horizontal, MeridianSpacing.lg)
                .frame(minHeight: MeridianTouchTarget.minSize + MeridianSpacing.sm)
                .foregroundStyle(MeridianColor.primary)
                .background(MeridianColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: MeridianRadius.control)
                        .strokeBorder(MeridianColor.primary, lineWidth: 4)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("What can I do here?")
            .accessibilityHint("Opens a plain explanation of every button on this screen")
        }
    }

    // MARK: Connection

    private var connectionBanner: some View {
        HStack(alignment: .top, spacing: MeridianSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(MeridianFont.heading(26))
                .accessibilityHidden(true)
            Text(HubCopy.connectionProblem)
                .font(MeridianFont.bodyStrong())
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(MeridianColor.warning)
        .padding(MeridianSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MeridianColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.control)
                .strokeBorder(MeridianColor.warning, lineWidth: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connection problem. \(HubCopy.connectionProblem)")
    }

    // MARK: Actions

    /// While a request is open the choice narrows — the status is the focus —
    /// but Emergency stays on screen so the resident is never trapped without
    /// a way to escalate, and Messages stays with it.
    @ViewBuilder
    private var actions: some View {
        if model.activeRequest != nil {
            VStack(spacing: MeridianTouchTarget.minSpacing) {
                HubActionButton(
                    symbol: "bell.fill",
                    title: "Emergency help",
                    note: "Use this if you need urgent help right now.",
                    style: .emergency,
                    busy: model.busyKind == HubBusyKind.request(.emergency),
                    locked: false,
                    action: { Task { await model.submitRequest(.emergency) } }
                )
                .accessibilityLabel("Urgent help")

                // Messages was originally dropped from this collapsed state as
                // "routine, not urgent". That was wrong in practice: an open
                // request can stay open for as long as it takes staff to
                // resolve it, and for that whole time the resident had no way
                // to reach their family at all. Waiting for a caregiver is
                // precisely when someone wants to say what happened. It sits
                // below Emergency and is styled calm, so it never competes
                // with the escalation path above it.
                HubActionButton(
                    symbol: "message.fill",
                    title: "Messages",
                    note: "Send a message to your family.",
                    style: .secondary,
                    busy: false,
                    locked: false,
                    action: { model.isMessagesOpen = true }
                )
            }
        } else {
            VStack(spacing: MeridianTouchTarget.minSpacing) {
                HubActionButton(
                    symbol: "hand.raised.fill",
                    title: "Request assistance",
                    note: "Ask a caregiver to come to your room.",
                    style: .primary,
                    busy: model.busyKind == HubBusyKind.request(.assistance),
                    locked: isLocked(for: .assistance),
                    action: { Task { await model.submitRequest(.assistance) } }
                )
                HubActionButton(
                    symbol: "phone.fill",
                    title: "Call family",
                    note: "Ask your family contact to call you.",
                    style: .secondary,
                    busy: model.busyKind == HubBusyKind.request(.familyContact),
                    locked: isLocked(for: .familyContact),
                    action: { Task { await model.submitRequest(.familyContact) } }
                )
                // Same secondary, calm styling as "Call family" — sending a
                // message is routine, not urgent, and opening the sheet is
                // instant local state, so it never has a `busy` state of its
                // own and is never locked out by another action in flight.
                HubActionButton(
                    symbol: "message.fill",
                    title: "Messages",
                    note: "Send a message to your family.",
                    style: .secondary,
                    busy: false,
                    locked: false,
                    action: { model.isMessagesOpen = true }
                )
                HubActionButton(
                    symbol: "bell.fill",
                    title: "Emergency help",
                    note: "Send an urgent alert to the care team now.",
                    style: .emergency,
                    busy: model.busyKind == HubBusyKind.request(.emergency),
                    // Emergency is deliberately never locked out by another
                    // pending action.
                    locked: false,
                    action: { Task { await model.submitRequest(.emergency) } }
                )
            }
            .accessibilityLabel("Ways to get help")
        }
    }

    private func isLocked(for kind: AssistanceKind) -> Bool {
        guard let busy = model.busyKind else { return false }
        return busy != HubBusyKind.request(kind)
    }
}

// MARK: - Action button

enum HubActionStyle {
    case primary, secondary, emergency

    var background: Color {
        switch self {
        case .primary: return MeridianColor.primary
        case .secondary: return MeridianColor.surface
        case .emergency: return MeridianColor.destructive
        }
    }

    var foreground: Color {
        switch self {
        case .primary, .emergency: return MeridianColor.onPrimary
        case .secondary: return MeridianColor.foreground
        }
    }

    var borderColor: Color? {
        self == .secondary ? MeridianColor.primary : nil
    }
}

struct HubActionButton: View {
    let symbol: String
    let title: String
    let note: String
    let style: HubActionStyle
    let busy: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                HStack(spacing: MeridianSpacing.md) {
                    // Icon + text, always. The icon never carries meaning alone.
                    if busy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(style.foreground)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: symbol)
                            .font(MeridianFont.action())
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(MeridianFont.action())
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Text(busy ? "Sending…" : note)
                    .font(MeridianFont.bodyStrong())
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(MeridianSpacing.lg)
            .frame(
                maxWidth: .infinity,
                minHeight: MeridianTouchTarget.primaryHeight,
                alignment: .leading
            )
            .foregroundStyle(style.foreground)
            .background(style.background)
            .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
            .overlay(
                Group {
                    if let border = style.borderColor {
                        RoundedRectangle(cornerRadius: MeridianRadius.control)
                            .strokeBorder(border, lineWidth: 4)
                    }
                }
            )
            .opacity(locked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busy || locked)
        .accessibilityLabel(title)
        .accessibilityHint(note)
        .accessibilityValue(busy ? "Sending" : "")
    }
}

// MARK: - Notice

/// Persistent by design. Nothing here auto-dismisses.
struct HubNoticeBanner: View {
    let notice: HubNotice

    private var symbol: String {
        switch notice.tone {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .working: return "arrow.triangle.2.circlepath"
        }
    }

    private var accent: Color {
        switch notice.tone {
        case .success: return MeridianColor.success
        case .error: return MeridianColor.destructive
        case .working: return MeridianColor.primary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: MeridianSpacing.sm) {
            Image(systemName: symbol)
                .font(MeridianFont.heading(26))
                .accessibilityHidden(true)
            Text(notice.text)
                .font(MeridianFont.bodyStrong(24))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(accent)
        .padding(MeridianSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MeridianColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.control)
                .strokeBorder(accent, lineWidth: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notice.text)
    }
}

// MARK: - Status card

struct HubStatusCard: View {
    let request: HubAssistanceRequest

    private var eta: HubCopy.Eta { HubCopy.eta(for: request) }

    private var accent: Color {
        switch request.status {
        case .enRoute, .resolved: return MeridianColor.success
        case .cancelled: return MeridianColor.warning
        case .open, .acknowledged: return MeridianColor.primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
            HStack(spacing: MeridianSpacing.xs) {
                Image(systemName: "checkmark.shield.fill")
                    .font(MeridianFont.body())
                    .accessibilityHidden(true)
                Text("Help status")
                    .font(MeridianFont.bodyStrong())
            }
            .foregroundStyle(MeridianColor.foregroundMuted)

            Text(HubCopy.statusHeading(for: request))
                .font(MeridianFont.heading())
                .foregroundStyle(MeridianColor.foreground)
                .fixedSize(horizontal: false, vertical: true)

            if request.status.isActive {
                // Position plus a check mark carry the progress — never colour
                // alone.
                VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                    ForEach(HubCopy.steps(for: request)) { step in
                        HStack(spacing: MeridianSpacing.sm) {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "clock")
                                .font(MeridianFont.bodyStrong())
                                .accessibilityHidden(true)
                            Text(step.label)
                                .font(MeridianFont.bodyStrong())
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(step.done ? MeridianColor.success : MeridianColor.foregroundMuted)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(step.done ? "Done: \(step.label)" : "Still waiting: \(step.label)")
                    }
                }
                .padding(.top, MeridianSpacing.xs)

                VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                    Text(eta.title)
                        .font(MeridianFont.bodyStrong(24))
                        .foregroundStyle(MeridianColor.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    // The caveat travels with the number, always. A bare
                    // estimate reads as a promise.
                    Text(eta.note)
                        .font(MeridianFont.body())
                        .foregroundStyle(MeridianColor.foregroundMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(MeridianSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MeridianColor.accentWash)
                .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(eta.title) \(eta.note)")
            } else {
                Text("You do not need to do anything else. Use the buttons below if you need help again.")
                    .font(MeridianFont.body())
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(MeridianSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MeridianColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.card)
                .strokeBorder(accent, lineWidth: 3)
        )
    }
}

// MARK: - Today's reminders

/// Tapping a medication row is a resident self-report, not a clinical
/// verification — it never names a drug, dose or instruction, and it locks
/// once tapped rather than allowing an "undo" of a real record. Meal/walk rows
/// are ordinary local checkboxes with nothing at stake.
struct HubRemindersCard: View {
    let rows: [HubReminderRow]
    let nextID: String?
    let onToggle: (HubReminderRow) -> Void

    private var doneCount: Int { rows.filter(\.done).count }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's reminders")
                    .font(MeridianFont.heading(26))
                    .foregroundStyle(MeridianColor.foreground)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: MeridianSpacing.sm)
                Text("\(doneCount) of \(rows.count) done")
                    .font(MeridianFont.bodyStrong())
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }

            Text("Tap a reminder when you've done it.")
                .font(MeridianFont.body())
                .foregroundStyle(MeridianColor.foregroundMuted)

            ProgressView(value: Double(doneCount), total: Double(max(rows.count, 1)))
                .tint(MeridianColor.success)
                .accessibilityLabel("Reminders finished")
                .accessibilityValue("\(doneCount) of \(rows.count) done")

            VStack(spacing: MeridianTouchTarget.minSpacing) {
                ForEach(rows) { row in
                    HubReminderRowView(
                        row: row,
                        isNext: row.id == nextID,
                        onToggle: { onToggle(row) }
                    )
                }
            }
            .padding(.top, MeridianSpacing.xs)
        }
        .padding(MeridianSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MeridianColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.card)
                .strokeBorder(MeridianColor.border, lineWidth: 3)
        )
        .accessibilityLabel("Today's reminders")
    }
}

struct HubReminderRowView: View {
    let row: HubReminderRow
    let isNext: Bool
    let onToggle: () -> Void

    private var symbol: String {
        switch row.kind {
        case .medication: return "pills.fill"
        case .meal: return "fork.knife"
        case .walk: return "figure.walk"
        }
    }

    private var isDisabled: Bool {
        row.busy || (row.done && row.locked)
    }

    private var traits: AccessibilityTraits {
        // A done row is announced as selected so VoiceOver conveys the
        // checked state the tick mark shows sighted users.
        row.done ? [.isButton, .isSelected] : .isButton
    }

    private var accessibilityDescription: String {
        var parts = [row.label, "at \(MeridianFormat.clockTime(row.time))"]
        if isNext { parts.append("up next") }
        if row.busy { parts.append("saving") }
        parts.append(row.done ? "done" : "not done yet")
        if row.done && row.locked {
            parts.append("this one is recorded and cannot be changed here")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: MeridianSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: MeridianRadius.control)
                        .fill(row.done ? MeridianColor.success : MeridianColor.accentWash)
                    if row.busy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(MeridianColor.primary)
                    } else {
                        Image(systemName: symbol)
                            .font(MeridianFont.bodyStrong(24))
                            .foregroundStyle(row.done ? MeridianColor.onPrimary : MeridianColor.primary)
                    }
                }
                .frame(width: MeridianTouchTarget.minSize, height: MeridianTouchTarget.minSize)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                    Text(row.label)
                        .font(MeridianFont.bodyStrong())
                        .strikethrough(row.done)
                        .foregroundStyle(
                            row.done ? MeridianColor.foregroundMuted : MeridianColor.foreground
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    // The web put the "Up next" pill beside the label; on a
                    // phone that squeezes the label, so it sits with the time
                    // instead. Nothing here drops below the 21pt floor, badge
                    // or not.
                    HStack(spacing: MeridianSpacing.xs) {
                        Text(MeridianFormat.clockTime(row.time))
                            .font(MeridianFont.body())
                            .foregroundStyle(MeridianColor.foregroundMuted)
                        if isNext {
                            Text("Up next")
                                .font(MeridianFont.bodyStrong())
                                .foregroundStyle(MeridianColor.onPrimary)
                                .padding(.horizontal, MeridianSpacing.xs)
                                .padding(.vertical, MeridianSpacing.unit)
                                .background(MeridianColor.primary)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer(minLength: MeridianSpacing.xs)

                // Check mark, not colour alone.
                ZStack {
                    Circle()
                        .strokeBorder(
                            row.done ? MeridianColor.success : MeridianColor.borderSoft,
                            lineWidth: 3
                        )
                        .background(Circle().fill(row.done ? MeridianColor.success : Color.clear))
                    if row.done {
                        Image(systemName: "checkmark")
                            .font(MeridianFont.bodyStrong())
                            .foregroundStyle(MeridianColor.onPrimary)
                    }
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            }
            .padding(MeridianSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: MeridianTouchTarget.minSize + MeridianSpacing.lg)
            .background(row.done ? MeridianColor.background : MeridianColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: MeridianRadius.control)
                    .strokeBorder(
                        isNext ? MeridianColor.primary : MeridianColor.borderSoft,
                        lineWidth: isNext ? 4 : 3
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(
            row.done && row.locked
                ? "Already recorded"
                : (row.done ? "Marks this as not done" : "Marks this as done")
        )
        .accessibilityAddTraits(traits)
    }
}

// MARK: - Visitor verification

struct HubVisitorCard: View {
    let prompt: HubVisitorPrompt
    let secondsLeft: Int
    let busy: Bool
    let locked: Bool
    let onAnswer: (VisitorPromptStatus) -> Void

    private var detail: String {
        let description = prompt.bodyDescription
            ?? "Someone we do not recognise was seen at the entrance."
        return "\(description) Seen at \(MeridianFormat.clockTime(prompt.detectedAt))."
    }

    /// The card used to disappear mid-decision when the prompt expired. The
    /// remaining time is now stated, and expiry is explained in place instead.
    private var countdown: String {
        if secondsLeft > 0 {
            return "You have about \(secondsLeft) second\(secondsLeft == 1 ? "" : "s") to answer. If you are unsure, choose “No, get help”."
        }
        return "This visitor check has closed because there was no answer. The care team was told to check for you."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
            HStack(spacing: MeridianSpacing.xs) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(MeridianFont.body())
                    .accessibilityHidden(true)
                Text("Visitor check")
                    .font(MeridianFont.bodyStrong())
            }
            .foregroundStyle(MeridianColor.foregroundMuted)

            Text("Is this person expected?")
                .font(MeridianFont.heading())
                .foregroundStyle(MeridianColor.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(detail)
                .font(MeridianFont.body(24))
                .foregroundStyle(MeridianColor.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)

            Text(countdown)
                .font(MeridianFont.bodyStrong())
                .foregroundStyle(MeridianColor.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(countdown)

            VStack(spacing: MeridianTouchTarget.minSpacing) {
                answerButton(
                    symbol: "checkmark.circle.fill",
                    title: "Yes, expected",
                    background: MeridianColor.success,
                    response: .approved
                )
                answerButton(
                    symbol: "bell.fill",
                    title: "No, get help",
                    background: MeridianColor.destructive,
                    response: .denied
                )
            }
            .padding(.top, MeridianSpacing.xs)
        }
        .padding(MeridianSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MeridianColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.card)
                .strokeBorder(MeridianColor.primary, lineWidth: 5)
        )
        .accessibilityLabel("Visitor check")
    }

    private func answerButton(
        symbol: String,
        title: String,
        background: Color,
        response: VisitorPromptStatus
    ) -> some View {
        Button {
            onAnswer(response)
        } label: {
            HStack(spacing: MeridianSpacing.sm) {
                if busy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(MeridianColor.onPrimary)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: symbol)
                        .font(MeridianFont.action())
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(MeridianFont.action())
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .padding(MeridianSpacing.md)
            .frame(maxWidth: .infinity, minHeight: MeridianTouchTarget.primaryHeight - MeridianSpacing.sm)
            .foregroundStyle(MeridianColor.onPrimary)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: MeridianRadius.control))
            .opacity(secondsLeft == 0 || locked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busy || locked || secondsLeft == 0)
        .accessibilityLabel(title)
        .accessibilityHint(
            secondsLeft == 0
                ? "This visitor check has closed"
                : (response == .denied
                    ? "Tells the care team to come and check"
                    : "Confirms you were expecting this person")
        )
        .accessibilityValue(busy ? "Saving" : "")
    }
}
