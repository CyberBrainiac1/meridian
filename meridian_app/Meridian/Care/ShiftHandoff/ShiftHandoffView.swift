import SwiftUI

struct ShiftHandoffView: View {
    @StateObject private var viewModel: ShiftHandoffViewModel

    init(facilityId: String) {
        _viewModel = StateObject(wrappedValue: ShiftHandoffViewModel(facilityId: facilityId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MeridianSpacing.md) {
                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(MeridianColor.destructiveStrong)
                    }

                    // "Who do I hand off to" comes first and stays first: it's
                    // the one question a caregiver walking off shift has to
                    // answer, and it shouldn't be below a scroll.
                    shiftBoard

                    if !viewModel.notes.isEmpty {
                        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                            Text("Handoff notes")
                                .font(MeridianFont.heading(20))
                                .foregroundStyle(MeridianColor.foreground)

                            ForEach(viewModel.sortedNotes) { note in
                                HandoffNoteCard(
                                    note: note,
                                    residentLabel: viewModel.residentLabel(for: note),
                                    isAcknowledging: viewModel.acknowledging.contains(note.id),
                                    onAcknowledge: { await viewModel.acknowledge(noteId: note.id) }
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                        Text("Last 8 hours")
                            .font(MeridianFont.heading(20))
                            .foregroundStyle(MeridianColor.foreground)

                        Text(viewModel.headline)
                            .font(MeridianFont.bodyMedium(17))
                            .foregroundStyle(MeridianColor.foreground)
                            .meridianCard()

                        if !viewModel.lines.isEmpty {
                            VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                                ForEach(viewModel.lines) { line in
                                    HStack(alignment: .top, spacing: MeridianSpacing.sm) {
                                        SeverityBadge(severity: line.severity)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(line.copy)
                                                .font(MeridianFont.body(15))
                                            Text("\(line.status.label) · \(MeridianFormat.clockTime(line.detectedAt))")
                                                .font(.caption)
                                                .foregroundStyle(MeridianColor.foregroundMuted)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .meridianCard()
                        }
                    }
                }
                .padding(MeridianSpacing.md)
            }
            .background(MeridianColor.background)
            .navigationTitle("Shift handoff")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CareHelpToolbarButton(topic: .handoff)
                }
            }
            .refreshable { await viewModel.load() }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var shiftBoard: some View {
        if viewModel.onNow == nil && viewModel.onNext == nil {
            Text("No caregiver shifts are scheduled right now.")
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foregroundMuted)
                .meridianCard()
        } else {
            VStack(spacing: MeridianSpacing.sm) {
                if let onNow = viewModel.onNow {
                    CaregiverShiftCard(shift: onNow, eyebrow: "On now", isCurrent: true)
                }
                if let onNext = viewModel.onNext {
                    CaregiverShiftCard(shift: onNext, eyebrow: "On next", isCurrent: false)
                }
            }
        }
    }
}

/// The handoff target. Name, role and window are all on screen at once so the
/// card answers "who, and until when" without a tap, and the call button is a
/// full-height primary control rather than a phone glyph.
private struct CaregiverShiftCard: View {
    let shift: CaregiverShift
    let eyebrow: String
    let isCurrent: Bool

    @Environment(\.openURL) private var openURL

    private var window: String {
        "\(MeridianFormat.clockTime(shift.startsAt)) – \(MeridianFormat.clockTime(shift.endsAt))"
    }

    /// tel: rejects spaces and punctuation, which is exactly what a hand-typed
    /// E.164 column tends to pick up.
    private var callURL: URL? {
        guard let raw = shift.phoneE164 else { return nil }
        let digits = raw.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
            Label(eyebrow, systemImage: isCurrent ? "person.fill.checkmark" : "clock.arrow.circlepath")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isCurrent ? MeridianColor.successStrong : MeridianColor.foregroundMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(shift.displayName)
                    .font(MeridianFont.heading(22))
                    .foregroundStyle(MeridianColor.foreground)
                Text(shift.roleLabel)
                    .font(MeridianFont.bodyMedium(15))
                    .foregroundStyle(MeridianColor.foregroundMuted)
                Text(window)
                    .font(MeridianFont.body(15))
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }

            if let callURL {
                Button {
                    openURL(callURL)
                } label: {
                    HStack {
                        Label("Call \(shift.displayName)", systemImage: "phone.fill")
                        Spacer()
                    }
                }
                .buttonStyle(MeridianButtonStyle(kind: isCurrent ? .primary : .secondary))
                .accessibilityLabel("Call \(shift.displayName), \(shift.roleLabel)")
            } else {
                Text("No phone number on file.")
                    .font(.footnote)
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .frame(minHeight: MeridianTouchTarget.minSize, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .meridianCard()
    }
}

private struct HandoffNoteCard: View {
    let note: HandoffNote
    let residentLabel: String
    let isAcknowledging: Bool
    let onAcknowledge: () async -> Void

    private var isUrgent: Bool { note.priority == .urgent }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
            HStack(alignment: .top, spacing: MeridianSpacing.xs) {
                HandoffPriorityBadge(priority: note.priority)
                Spacer()
                Text(MeridianFormat.relativeTime(note.createdAt))
                    .font(.caption)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }

            Text(residentLabel)
                .font(MeridianFont.bodyMedium(17))
                .foregroundStyle(MeridianColor.foreground)

            Text(note.body)
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foreground)
                .fixedSize(horizontal: false, vertical: true)

            Text("Written by \(note.authorName)")
                .font(.caption)
                .foregroundStyle(MeridianColor.foregroundMuted)

            if let acknowledgedAt = note.acknowledgedAt {
                // acknowledge_handoff_note records the time, not the person, so
                // this states what's actually known rather than inventing a name.
                Label(
                    "Acknowledged \(MeridianFormat.relativeTime(acknowledgedAt)) · \(MeridianFormat.clockTime(acknowledgedAt))",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(MeridianColor.successStrong)
                .frame(minHeight: MeridianTouchTarget.minSize, alignment: .leading)
            } else {
                Button {
                    Task { await onAcknowledge() }
                } label: {
                    HStack {
                        Text("Acknowledge")
                        Spacer()
                        if isAcknowledging { ProgressView().tint(MeridianColor.foreground) }
                    }
                }
                .buttonStyle(MeridianButtonStyle(kind: .secondary))
                .disabled(isAcknowledging)
                .accessibilityLabel("Acknowledge note about \(residentLabel)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MeridianSpacing.md)
        .background(
            (isUrgent ? MeridianColor.destructive.opacity(0.06) : MeridianColor.surface),
            in: RoundedRectangle(cornerRadius: MeridianRadius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.card)
                .stroke(isUrgent ? MeridianColor.destructive : MeridianColor.border, lineWidth: isUrgent ? 2 : 1)
        )
    }
}

/// Mirrors SeverityBadge: base colour as a 12% tint behind the *Strong text
/// colour, because the base colour on its own tint fails 4.5:1.
private struct HandoffPriorityBadge: View {
    let priority: HandoffPriority

    private var tintColor: Color {
        switch priority {
        case .routine: return MeridianColor.primary
        case .watch: return MeridianColor.warning
        case .urgent: return MeridianColor.destructive
        }
    }

    private var textColor: Color {
        switch priority {
        case .routine: return MeridianColor.primary
        case .watch: return MeridianColor.warningStrong
        case .urgent: return MeridianColor.destructiveStrong
        }
    }

    private var systemImage: String {
        switch priority {
        case .routine: return "text.bubble.fill"
        case .watch: return "eye.fill"
        case .urgent: return "exclamationmark.octagon.fill"
        }
    }

    var body: some View {
        Label(priority.label, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tintColor.opacity(0.12), in: Capsule())
            .accessibilityLabel(priority.label)
    }
}
