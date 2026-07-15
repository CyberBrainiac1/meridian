import SwiftUI

struct VisitorLogView: View {
    @StateObject private var viewModel = VisitorLogViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MeridianSpacing.md) {
                    // Count/timeline only — never a name. The view has no
                    // name column, so this is structurally enforced, not
                    // just a UI convention.
                    HStack(spacing: MeridianSpacing.sm) {
                        Image(systemName: "figure.wave")
                            .font(.system(size: 24))
                            .foregroundStyle(MeridianColor.primary)
                        Text("\(viewModel.todayCount) visitor\(viewModel.todayCount == 1 ? "" : "s") today")
                            .font(MeridianFont.heading(20))
                    }
                    .meridianCard()

                    if viewModel.visitors.isEmpty {
                        Text("No visitor activity recorded yet. This shows up once your facility enables visitor visibility for your family link.")
                            .font(MeridianFont.body(15))
                            .foregroundStyle(MeridianColor.foreground.opacity(0.6))
                            .padding(.top, MeridianSpacing.sm)
                    } else {
                        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                            ForEach(Array(viewModel.visitors.enumerated()), id: \.offset) { _, visitor in
                                HStack(spacing: MeridianSpacing.sm) {
                                    Image(systemName: "door.left.hand.open")
                                        .foregroundStyle(MeridianColor.primaryAlt)
                                    Text("Visitor at \(visitor.detectedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(MeridianFont.body(15))
                                    Spacer()
                                }
                            }
                        }
                        .meridianCard()
                    }
                }
                .padding(MeridianSpacing.md)
            }
            .background(MeridianColor.background)
            .navigationTitle("Visitors")
            .refreshable { await viewModel.load() }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
