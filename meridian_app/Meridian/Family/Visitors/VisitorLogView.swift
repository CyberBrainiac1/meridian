import SwiftUI

struct VisitorLogView: View {
    @StateObject private var viewModel = VisitorLogViewModel()
    @State private var isShowingHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FamSpacing.md) {
                    // Count/timeline only — never a name. The view has no
                    // name column, so this is structurally enforced, not
                    // just a UI convention.
                    HStack(spacing: FamSpacing.sm) {
                        Image(systemName: "figure.wave")
                            .font(.system(size: 24))
                            .foregroundStyle(FamColor.primary)
                        Text("\(viewModel.todayCount) visitor\(viewModel.todayCount == 1 ? "" : "s") today")
                            .font(FamFont.heading(20))
                    }
                    .famCard()

                    if viewModel.visitors.isEmpty {
                        Text("No visitor activity recorded yet. This shows up once your facility enables visitor visibility for your family link.")
                            .font(FamFont.body(15))
                            .foregroundStyle(FamColor.foregroundMuted)
                            .padding(.top, FamSpacing.sm)
                    } else {
                        VStack(alignment: .leading, spacing: FamSpacing.sm) {
                            ForEach(Array(viewModel.visitors.enumerated()), id: \.offset) { _, visitor in
                                HStack(spacing: FamSpacing.sm) {
                                    Image(systemName: "person.text.rectangle.fill")
                                        .foregroundStyle(FamColor.primaryAlt)
                                    Text("Visitor at \(visitor.detectedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(FamFont.body(15))
                                    Spacer()
                                }
                            }
                        }
                        .famCard()
                    }
                }
                .padding(FamSpacing.md)
            }
            .background(FamColor.background)
            .navigationTitle("Visitors")
            .refreshable { await viewModel.load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .frame(minWidth: FamTouchTarget.minSize, minHeight: FamTouchTarget.minSize)
                    }
                    .accessibilityLabel("Help")
                }
            }
            .sheet(isPresented: $isShowingHelp) {
                FamHelpTourView(topic: .visitors)
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
