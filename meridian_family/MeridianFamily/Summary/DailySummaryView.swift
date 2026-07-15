import SwiftUI

struct DailySummaryView: View {
    @StateObject private var viewModel: DailySummaryViewModel

    init(residents: [FamilyLinkedResident]) {
        _viewModel = StateObject(wrappedValue: DailySummaryViewModel(residents: residents))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MeridianSpacing.md) {
                    ForEach(viewModel.summaries) { summary in
                        VStack(alignment: .leading, spacing: MeridianSpacing.sm) {
                            HStack(spacing: MeridianSpacing.sm) {
                                Image(systemName: summary.todayIncidents.contains { $0.severity != .info } ? "heart.text.square" : "sun.max.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(MeridianColor.success)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.headline)
                                        .font(MeridianFont.heading(20))
                                        .foregroundStyle(MeridianColor.foreground)
                                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                                        .font(.footnote)
                                        .foregroundStyle(MeridianColor.foreground.opacity(0.6))
                                }
                            }
                            Text(summary.detailLine)
                                .font(MeridianFont.body(16))
                                .foregroundStyle(MeridianColor.foreground.opacity(0.85))

                            if !summary.todayIncidents.isEmpty {
                                Divider().padding(.vertical, MeridianSpacing.unit)
                                VStack(alignment: .leading, spacing: MeridianSpacing.xs) {
                                    ForEach(summary.todayIncidents) { incident in
                                        HStack(alignment: .top, spacing: MeridianSpacing.xs) {
                                            Circle()
                                                .fill(incident.severity == .info ? MeridianColor.primary : MeridianColor.warning)
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 6)
                                            Text(incident.summary ?? incident.eventType.label)
                                                .font(MeridianFont.body(14))
                                                .foregroundStyle(MeridianColor.foreground.opacity(0.8))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(MeridianSpacing.lg)
                        .background(MeridianColor.success.opacity(0.06), in: RoundedRectangle(cornerRadius: MeridianRadius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: MeridianRadius.card)
                                .stroke(MeridianColor.success.opacity(0.2), lineWidth: 1)
                        )
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(MeridianColor.warning)
                    }
                }
                .padding(MeridianSpacing.md)
            }
            .background(MeridianColor.background)
            .navigationTitle("Today")
            .refreshable { await viewModel.load() }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
