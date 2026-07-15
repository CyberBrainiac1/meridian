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
                .padding(MeridianSpacing.md)
            }
            .background(MeridianColor.background)
            .navigationTitle("Shift handoff")
            .refreshable { await viewModel.load() }
        }
        .task { await viewModel.load() }
    }
}
