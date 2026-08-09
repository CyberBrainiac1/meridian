import SwiftUI

/// Short guided tour for one topic, presented as a sheet from that tab's
/// "?" button.
///
/// Every step is reachable two ways — swipe the page, or use Back/Next.
/// Swipe alone would be undiscoverable for the audience this app is built
/// for, and unusable with Switch Control or VoiceOver. Close is present on
/// every step, so nobody is ever paged through to the end to escape.
///
/// The progress indicator differs by size and shape as well as fill, and
/// is backed by a literal "Step 2 of 3" counter, so position is never
/// communicated by colour alone.
struct HelpTourView: View {
    let topic: HelpTopic

    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0

    private let steps: [HelpStep]

    init(topic: HelpTopic) {
        self.topic = topic
        self.steps = topic.steps
    }

    private var isLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: MeridianSpacing.md) {
                TabView(selection: $stepIndex) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        HelpStepPage(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: MeridianSpacing.sm) {
                    HStack(spacing: MeridianSpacing.xs) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                            Capsule()
                                .fill(index == stepIndex ? MeridianColor.primary : MeridianColor.border)
                                .frame(width: index == stepIndex ? 28 : 8, height: 8)
                        }
                    }
                    // The counter below says the same thing in words, and
                    // is the version VoiceOver reads.
                    .accessibilityHidden(true)

                    Text("Step \(stepIndex + 1) of \(steps.count)")
                        .font(MeridianFont.bodyMedium(15))
                        .foregroundStyle(MeridianColor.foregroundMuted)

                    HStack(spacing: MeridianTouchTarget.minSpacing) {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: MeridianMotion.duration)) {
                                stepIndex = max(stepIndex - 1, 0)
                            }
                        }
                        .buttonStyle(MeridianButtonStyle(kind: .secondary))
                        .disabled(stepIndex == 0)

                        Button(isLastStep ? "Done" : "Next") {
                            if isLastStep {
                                dismiss()
                            } else {
                                withAnimation(.easeInOut(duration: MeridianMotion.duration)) {
                                    stepIndex = min(stepIndex + 1, steps.count - 1)
                                }
                            }
                        }
                        .buttonStyle(MeridianButtonStyle(kind: .primary))
                    }
                }
                .padding(.horizontal, MeridianSpacing.md)
                .padding(.bottom, MeridianSpacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MeridianColor.background)
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Text, not a glyph, and on every step — leaving the tour
                // should never require finishing it.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .frame(minWidth: MeridianTouchTarget.minSize, minHeight: MeridianTouchTarget.minSize)
                }
            }
        }
    }
}

private struct HelpStepPage: View {
    let step: HelpStep

    var body: some View {
        ScrollView {
            VStack(spacing: MeridianSpacing.md) {
                Image(systemName: step.symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(MeridianColor.primary)
                    .accessibilityHidden(true)
                    .padding(.top, MeridianSpacing.lg)

                Text(step.title)
                    .font(MeridianFont.heading(24))
                    .foregroundStyle(MeridianColor.foreground)
                    .multilineTextAlignment(.center)

                Text(step.body)
                    .font(MeridianFont.body(17))
                    .foregroundStyle(MeridianColor.foregroundMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MeridianSpacing.lg)
            .padding(.bottom, MeridianSpacing.md)
        }
    }
}
