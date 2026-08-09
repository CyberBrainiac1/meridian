import SwiftUI

/// The "?" that opens the tour for whichever screen the caregiver is on.
/// Owns its own presentation state so each screen adds one line to its
/// toolbar rather than a `@State` flag plus a `.sheet` of its own.
struct HelpToolbarButton: View {
    let topic: HelpTopic

    @State private var isShowingTour = false

    var body: some View {
        Button {
            isShowingTour = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(MeridianFont.bodyMedium(20))
        }
        .frame(minWidth: MeridianTouchTarget.minSize, minHeight: MeridianTouchTarget.minSize)
        .accessibilityLabel("Help")
        .sheet(isPresented: $isShowingTour) {
            HelpTourView(topic: topic)
        }
    }
}

/// A paged walkthrough of one screen. Swipe and the buttons both move between
/// steps — swipe alone would be invisible to anyone who hasn't been shown it,
/// and unusable with VoiceOver on. Everything is sized for a glance at arm's
/// length with one hand, because that's when it gets opened.
struct HelpTourView: View {
    let topic: HelpTopic

    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0

    private var steps: [HelpStep] { topic.steps }
    private var isFirstStep: Bool { stepIndex <= 0 }
    private var isLastStep: Bool { stepIndex >= steps.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: MeridianSpacing.md) {
                progressIndicator

                TabView(selection: $stepIndex) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { offset, step in
                        HelpStepPage(step: step)
                            .tag(offset)
                    }
                }
                // The built-in dots are replaced by `progressIndicator`,
                // which says the position in words as well as in colour.
                .tabViewStyle(.page(indexDisplayMode: .never))

                navigationButtons
            }
            .padding(MeridianSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MeridianColor.background)
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Reachable on every step, including the last one — a
                // caregiver who opened this by accident mid-shift shouldn't
                // have to page to the end to get out.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .frame(minWidth: MeridianTouchTarget.minSize, minHeight: MeridianTouchTarget.minSize)
                        .accessibilityLabel("Close help")
                }
            }
        }
        .onAppear { announceStep() }
        .onChange(of: stepIndex) { _, _ in announceStep() }
    }

    /// Position is never carried by colour alone: the counter states it in
    /// words, and a completed segment differs in height as well as in fill.
    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
            Text("Step \(stepIndex + 1) of \(steps.count)")
                .font(MeridianFont.bodyMedium(15))
                .foregroundStyle(MeridianColor.foregroundMuted)

            HStack(spacing: MeridianSpacing.unit) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= stepIndex ? MeridianColor.primary : MeridianColor.muted)
                        .frame(height: index <= stepIndex ? MeridianSpacing.xs : MeridianSpacing.unit)
                }
            }
            .frame(height: MeridianSpacing.xs)
            .animation(.easeInOut(duration: MeridianMotion.duration), value: stepIndex)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(stepIndex + 1) of \(steps.count)")
    }

    private var navigationButtons: some View {
        HStack(spacing: MeridianTouchTarget.minSpacing) {
            Button {
                goToStep(stepIndex - 1)
            } label: {
                Text("Back").frame(maxWidth: .infinity)
            }
            .buttonStyle(MeridianButtonStyle(kind: .secondary))
            // Hidden rather than removed on the first step: Next must not
            // move sideways under a thumb that's already reaching for it.
            .opacity(isFirstStep ? 0 : 1)
            .disabled(isFirstStep)
            .accessibilityHidden(isFirstStep)

            Button {
                if isLastStep {
                    dismiss()
                } else {
                    goToStep(stepIndex + 1)
                }
            } label: {
                Text(isLastStep ? "Done" : "Next").frame(maxWidth: .infinity)
            }
            .buttonStyle(MeridianButtonStyle(kind: .primary))
        }
    }

    private func goToStep(_ index: Int) {
        guard steps.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: MeridianMotion.duration)) {
            stepIndex = index
        }
    }

    /// Swiping between pages moves VoiceOver focus without saying what
    /// changed, so the step is announced explicitly however it was reached.
    private func announceStep() {
        guard steps.indices.contains(stepIndex) else { return }
        let step = steps[stepIndex]
        AccessibilityNotification.Announcement(
            "Step \(stepIndex + 1) of \(steps.count). \(step.title)"
        )
        .post()
    }
}

private struct HelpStepPage: View {
    let step: HelpStep

    var body: some View {
        // Scrolls rather than truncates: the longest steps run past a small
        // screen once Dynamic Type is turned up.
        ScrollView {
            VStack(spacing: MeridianSpacing.md) {
                Image(systemName: step.systemImage)
                    .font(MeridianFont.heading(48))
                    .foregroundStyle(MeridianColor.primary)
                    .padding(MeridianSpacing.lg)
                    .background(MeridianColor.primary.opacity(0.12), in: Circle())
                    // Decorative — the title says the same thing in words.
                    .accessibilityHidden(true)

                Text(step.title)
                    .font(MeridianFont.heading(26))
                    .foregroundStyle(MeridianColor.foreground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.body)
                    .font(MeridianFont.body(18))
                    .foregroundStyle(MeridianColor.foreground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MeridianSpacing.lg)
            .padding(.horizontal, MeridianSpacing.xs)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityElement(children: .combine)
    }
}
