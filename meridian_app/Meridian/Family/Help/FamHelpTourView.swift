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
struct FamHelpTourView: View {
    let topic: FamHelpTopic

    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0

    private let steps: [FamHelpStep]

    init(topic: FamHelpTopic) {
        self.topic = topic
        self.steps = topic.steps
    }

    private var isLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: FamSpacing.md) {
                TabView(selection: $stepIndex) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        FamHelpStepPage(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: FamSpacing.sm) {
                    HStack(spacing: FamSpacing.xs) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, _ in
                            Capsule()
                                .fill(index == stepIndex ? FamColor.primary : FamColor.border)
                                .frame(width: index == stepIndex ? 28 : 8, height: 8)
                        }
                    }
                    // The counter below says the same thing in words, and
                    // is the version VoiceOver reads.
                    .accessibilityHidden(true)

                    Text("Step \(stepIndex + 1) of \(steps.count)")
                        .font(FamFont.bodyMedium(15))
                        .foregroundStyle(FamColor.foregroundMuted)

                    HStack(spacing: FamTouchTarget.minSpacing) {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: FamMotion.duration)) {
                                stepIndex = max(stepIndex - 1, 0)
                            }
                        }
                        .buttonStyle(FamButtonStyle(kind: .secondary))
                        .disabled(stepIndex == 0)

                        Button(isLastStep ? "Done" : "Next") {
                            if isLastStep {
                                dismiss()
                            } else {
                                withAnimation(.easeInOut(duration: FamMotion.duration)) {
                                    stepIndex = min(stepIndex + 1, steps.count - 1)
                                }
                            }
                        }
                        .buttonStyle(FamButtonStyle(kind: .primary))
                    }
                }
                .padding(.horizontal, FamSpacing.md)
                .padding(.bottom, FamSpacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FamColor.background)
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Text, not a glyph, and on every step — leaving the tour
                // should never require finishing it.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .frame(minWidth: FamTouchTarget.minSize, minHeight: FamTouchTarget.minSize)
                }
            }
        }
    }
}

private struct FamHelpStepPage: View {
    let step: FamHelpStep

    var body: some View {
        ScrollView {
            VStack(spacing: FamSpacing.md) {
                Image(systemName: step.symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(FamColor.primary)
                    .accessibilityHidden(true)
                    .padding(.top, FamSpacing.lg)

                Text(step.title)
                    .font(FamFont.heading(24))
                    .foregroundStyle(FamColor.foreground)
                    .multilineTextAlignment(.center)

                Text(step.body)
                    .font(FamFont.body(17))
                    .foregroundStyle(FamColor.foregroundMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FamSpacing.lg)
            .padding(.bottom, FamSpacing.md)
        }
    }
}
