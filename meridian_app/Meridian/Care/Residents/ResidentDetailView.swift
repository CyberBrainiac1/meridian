import SwiftUI

/// Ordered safety-critical first. A caregiver reading this at 03:00 reads
/// top-down and stops when they have what they came for, so allergies and
/// code status sit above everything, and the medication chart above the
/// narrative care notes.
struct ResidentDetailView: View {
    let resident: ResidentProfile

    @StateObject private var viewModel: ResidentDetailViewModel
    @Environment(\.openURL) private var openURL
    @State private var callError: String?

    init(resident: ResidentProfile) {
        self.resident = resident
        _viewModel = StateObject(wrappedValue: ResidentDetailViewModel(residentId: resident.personId))
    }

    private var alertMessage: String? {
        viewModel.actionError ?? callError
    }

    private var careDetails: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if let notes = resident.careNotes { rows.append(("Care notes", notes)) }
        if let mobility = resident.mobilityStatus { rows.append(("Mobility", mobility)) }
        if let communication = resident.communicationNotes { rows.append(("Communication", communication)) }
        if let dietary = resident.dietaryNeeds { rows.append(("Dietary needs", dietary)) }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeridianSpacing.md) {
                header

                CriticalSafetyBanner(
                    allergies: resident.allergies ?? [],
                    codeStatus: resident.codeStatus
                )

                medications

                schedule

                if !careDetails.isEmpty {
                    DetailSection(title: "Care notes") {
                        ForEach(careDetails, id: \.label) { row in
                            LabeledBlock(label: row.label, value: row.value)
                        }
                    }
                }

                contacts

                if !viewModel.handoffNotes.isEmpty {
                    DetailSection(title: "Recent handoff notes") {
                        ForEach(viewModel.handoffNotes) { note in
                            HandoffNoteRow(note: note)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MeridianColor.warningStrong)
                }
            }
            .padding(MeridianSpacing.md)
        }
        .background(MeridianColor.background)
        .navigationTitle(resident.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .alert("Couldn't complete that", isPresented: .constant(alertMessage != nil), actions: {
            Button("OK") {
                viewModel.actionError = nil
                callError = nil
            }
        }, message: {
            Text(alertMessage ?? "")
        })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.unit) {
            Text(resident.displayName)
                .font(MeridianFont.heading(24))
                .foregroundStyle(MeridianColor.foreground)
            Text(subtitle)
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foregroundMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .meridianCard()
    }

    private var subtitle: String {
        var parts = [resident.roomId ?? "Room unassigned"]
        if let age = resident.age { parts.append("\(age) years old") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var medications: some View {
        DetailSection(title: "Today's medications") {
            if viewModel.doses.isEmpty {
                Text("No scheduled medications.")
                    .font(MeridianFont.body(15))
                    .foregroundStyle(MeridianColor.foregroundMuted)
            } else {
                ForEach(viewModel.doses) { dose in
                    MedicationDoseRow(
                        dose: dose,
                        isRecording: viewModel.isRecording(dose)
                    ) { status in
                        Task { await viewModel.record(dose, as: status) }
                    }
                }
            }

            if !viewModel.prnMedications.isEmpty {
                Text("As needed")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .padding(.top, MeridianSpacing.unit)
                ForEach(viewModel.prnMedications) { medication in
                    PrnMedicationRow(medication: medication)
                }
            }
        }
    }

    @ViewBuilder
    private var schedule: some View {
        DetailSection(title: "Today's schedule") {
            if viewModel.activitySlots.isEmpty {
                Text("No scheduled activities.")
                    .font(MeridianFont.body(15))
                    .foregroundStyle(MeridianColor.foregroundMuted)
            } else {
                ForEach(viewModel.activitySlots) { slot in
                    ActivitySlotRow(
                        slot: slot,
                        isRecording: viewModel.isRecording(slot)
                    ) { status in
                        Task { await viewModel.record(slot, as: status) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contacts: some View {
        if !viewModel.contacts.isEmpty {
            DetailSection(title: "Emergency contacts") {
                ForEach(viewModel.contacts) { contact in
                    HStack(alignment: .center, spacing: MeridianSpacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: MeridianSpacing.xs) {
                                Text(contact.displayName)
                                    .font(MeridianFont.bodyMedium(16))
                                    .foregroundStyle(MeridianColor.foreground)
                                if contact.isPrimary {
                                    Text("Primary")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(MeridianColor.primary.opacity(0.12), in: Capsule())
                                        .foregroundStyle(MeridianColor.primary)
                                }
                            }
                            Text("\(contact.relationship) · \(contact.phoneE164)")
                                .font(.footnote)
                                .foregroundStyle(MeridianColor.foregroundMuted)
                            if let notes = contact.notes {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundStyle(MeridianColor.foregroundMuted)
                            }
                        }
                        Spacer(minLength: MeridianTouchTarget.minSpacing)
                        Button {
                            call(contact)
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(MeridianColor.onPrimary)
                                .frame(
                                    width: MeridianTouchTarget.minSize,
                                    height: MeridianTouchTarget.minSize
                                )
                                .background(MeridianColor.primary, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Call \(contact.displayName), \(contact.relationship)")
                    }
                }
            }
        }
    }

    /// `tel:` refuses anything with spaces or punctuation, and phone_e164 is
    /// only conventionally E.164 — strip it back to digits and a leading plus
    /// rather than trusting the column. The completion handler covers the
    /// device that can't place calls at all (iPad, Simulator), where the
    /// number itself is the useful thing to show.
    private func call(_ contact: EmergencyContact) {
        let digits = contact.phoneE164.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else {
            callError = "No dialable number on file for \(contact.displayName)."
            return
        }
        openURL(url) { accepted in
            if !accepted {
                callError = "This device can't place calls. Dial \(contact.phoneE164) for \(contact.displayName)."
            }
        }
    }
}

/// Allergies and code status, or nothing at all — an empty red box reads as
/// "checked and clear", which is the opposite of what a null column means.
private struct CriticalSafetyBanner: View {
    let allergies: [String]
    let codeStatus: CodeStatus?

    private var isEmpty: Bool { allergies.isEmpty && codeStatus == nil }

    var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                Label("Critical safety", systemImage: "exclamationmark.octagon.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(MeridianColor.destructiveStrong)

                if !allergies.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allergies")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MeridianColor.destructiveStrong)
                        Text(allergies.joined(separator: ", "))
                            .font(MeridianFont.bodyMedium(17))
                            .foregroundStyle(MeridianColor.destructiveStrong)
                    }
                }

                if let codeStatus {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Code status")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MeridianColor.foregroundMuted)
                        if codeStatus.isRestricted {
                            Label(codeStatus.label, systemImage: "exclamationmark.triangle.fill")
                                .font(MeridianFont.bodyMedium(17))
                                .foregroundStyle(MeridianColor.destructiveStrong)
                        } else {
                            Text(codeStatus.label)
                                .font(MeridianFont.bodyMedium(17))
                                .foregroundStyle(MeridianColor.foreground)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MeridianSpacing.md)
            .background(
                MeridianColor.destructive.opacity(0.10),
                in: RoundedRectangle(cornerRadius: MeridianRadius.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MeridianRadius.card)
                    .stroke(MeridianColor.destructive, lineWidth: 2)
            )
            .accessibilityElement(children: .combine)
        }
    }
}

private struct MedicationDoseRow: View {
    let dose: MedicationDose
    let isRecording: Bool
    let onRecord: (CareMedicationDoseStatus) -> Void

    private static let actions: [CareMedicationDoseStatus] = [.given, .refused, .held]

    private var statusLabel: String {
        dose.isOverdue ? "Overdue" : dose.status.label
    }

    private var statusColor: Color {
        if dose.isOverdue { return MeridianColor.destructiveStrong }
        switch dose.status {
        case .outstanding: return MeridianColor.primary
        case .given: return MeridianColor.successStrong
        case .refused, .held: return MeridianColor.warningStrong
        case .missed: return MeridianColor.destructiveStrong
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: MeridianSpacing.xs) {
                Text(MeridianFormat.clockTime(dose.scheduledFor))
                    .font(MeridianFont.bodyMedium(17))
                    .foregroundStyle(dose.isOverdue ? MeridianColor.destructiveStrong : MeridianColor.foreground)
                Spacer()
                if isRecording {
                    ProgressView().tint(MeridianColor.foregroundMuted)
                }
                Text(statusLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            Text("\(dose.medicationName) · \(dose.dose)")
                .font(MeridianFont.bodyMedium(16))
                .foregroundStyle(MeridianColor.foreground)
            Text(dose.route)
                .font(.footnote)
                .foregroundStyle(MeridianColor.foregroundMuted)
            if let instructions = dose.instructions {
                Text(instructions)
                    .font(.footnote)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }
            if let administeredAt = dose.administeredAt, dose.status != .outstanding {
                Text("Recorded \(MeridianFormat.clockTime(administeredAt))")
                    .font(.caption)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }
            if let note = dose.administrationNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }

            if dose.status == .outstanding {
                HStack(spacing: MeridianTouchTarget.minSpacing) {
                    ForEach(Self.actions, id: \.self) { status in
                        Button {
                            onRecord(status)
                        } label: {
                            Text(status.label)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MeridianButtonStyle(kind: status == .given ? .success : .secondary))
                        .disabled(isRecording)
                        .accessibilityLabel("\(status.label) — \(dose.medicationName) at \(MeridianFormat.clockTime(dose.scheduledFor))")
                    }
                }
                .padding(.top, MeridianSpacing.unit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MeridianSpacing.sm)
        .background(
            (dose.isOverdue ? MeridianColor.destructive.opacity(0.08) : MeridianColor.background),
            in: RoundedRectangle(cornerRadius: MeridianRadius.control)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.control)
                .stroke(
                    dose.isOverdue ? MeridianColor.destructive : MeridianColor.border,
                    lineWidth: dose.isOverdue ? 2 : 1
                )
        )
    }
}

private struct ActivitySlotRow: View {
    let slot: ActivitySlot
    let isRecording: Bool
    let onRecord: (CareActivityCompletionStatus) -> Void

    private static let actions: [CareActivityCompletionStatus] = [.done, .skipped, .missed]

    private var statusLabel: String {
        slot.isOverdue ? "Overdue" : slot.status.label
    }

    private var statusColor: Color {
        if slot.isOverdue { return MeridianColor.destructiveStrong }
        switch slot.status {
        case .outstanding: return MeridianColor.primary
        case .done: return MeridianColor.successStrong
        case .skipped: return MeridianColor.warningStrong
        case .missed: return MeridianColor.destructiveStrong
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: MeridianSpacing.xs) {
                Text(MeridianFormat.clockTime(slot.scheduledFor))
                    .font(MeridianFont.bodyMedium(17))
                    .foregroundStyle(slot.isOverdue ? MeridianColor.destructiveStrong : MeridianColor.foreground)
                Spacer()
                if isRecording {
                    ProgressView().tint(MeridianColor.foregroundMuted)
                }
                Text(statusLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            Label(slot.label, systemImage: slot.activityType.symbolName)
                .font(MeridianFont.bodyMedium(16))
                .foregroundStyle(MeridianColor.foreground)

            if let completionNote = slot.completionNote {
                Text(completionNote)
                    .font(.caption)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }

            if slot.status == .outstanding {
                HStack(spacing: MeridianTouchTarget.minSpacing) {
                    ForEach(Self.actions, id: \.self) { status in
                        Button {
                            onRecord(status)
                        } label: {
                            Text(status.label)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MeridianButtonStyle(kind: status == .done ? .success : .secondary))
                        .disabled(isRecording)
                        .accessibilityLabel("\(status.label) — \(slot.label) at \(MeridianFormat.clockTime(slot.scheduledFor))")
                    }
                }
                .padding(.top, MeridianSpacing.unit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MeridianSpacing.sm)
        .background(
            (slot.isOverdue ? MeridianColor.destructive.opacity(0.08) : MeridianColor.background),
            in: RoundedRectangle(cornerRadius: MeridianRadius.control)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.control)
                .stroke(
                    slot.isOverdue ? MeridianColor.destructive : MeridianColor.border,
                    lineWidth: slot.isOverdue ? 2 : 1
                )
        )
    }
}

private struct PrnMedicationRow: View {
    let medication: Medication

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(medication.medicationName) · \(medication.dose)")
                .font(MeridianFont.bodyMedium(16))
                .foregroundStyle(MeridianColor.foreground)
            Text(medication.route)
                .font(.footnote)
                .foregroundStyle(MeridianColor.foregroundMuted)
            if !medication.scheduleTimes.isEmpty {
                Text(medication.scheduleTimes.map(MeridianFormat.scheduleTime).joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }
            if let instructions = medication.instructions {
                Text(instructions)
                    .font(.footnote)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MeridianSpacing.sm)
        .background(MeridianColor.background, in: RoundedRectangle(cornerRadius: MeridianRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: MeridianRadius.control)
                .stroke(MeridianColor.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct HandoffNoteRow: View {
    let note: HandoffNote

    private var priorityColor: Color {
        switch note.priority {
        case .routine: return MeridianColor.foregroundMuted
        case .watch: return MeridianColor.warningStrong
        case .urgent: return MeridianColor.destructiveStrong
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.unit) {
            HStack(spacing: MeridianSpacing.xs) {
                Text(note.priority.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(priorityColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(priorityColor)
                Spacer()
                Text(MeridianFormat.relativeTime(note.createdAt))
                    .font(.caption)
                    .foregroundStyle(MeridianColor.foregroundMuted)
            }
            Text(note.body)
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foreground)
            Text(note.authorName)
                .font(.caption)
                .foregroundStyle(MeridianColor.foregroundMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct LabeledBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MeridianColor.foregroundMuted)
            Text(value)
                .font(MeridianFont.body(15))
                .foregroundStyle(MeridianColor.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
            Text(title)
                .font(MeridianFont.heading(17))
                .foregroundStyle(MeridianColor.foreground)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .meridianCard()
    }
}
