import SwiftUI

struct DailySummaryView: View {
    @StateObject private var viewModel: DailySummaryViewModel

    init(residents: [FamilyLinkedResident]) {
        _viewModel = StateObject(wrappedValue: DailySummaryViewModel(residents: residents))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FamSpacing.md) {
                    ForEach(viewModel.summaries) { summary in
                        VStack(alignment: .leading, spacing: FamSpacing.sm) {
                            HStack(spacing: FamSpacing.sm) {
                                Image(systemName: summary.todayIncidents.contains { $0.severity != .info } ? "heart.text.square" : "sun.max.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(FamColor.success)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.headline)
                                        .font(FamFont.heading(20))
                                        .foregroundStyle(FamColor.foreground)
                                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                                        .font(.footnote)
                                        .foregroundStyle(FamColor.foregroundMuted)
                                }
                            }
                            Text(summary.detailLine)
                                .font(FamFont.body(16))
                                .foregroundStyle(FamColor.foregroundMuted)

                            if !summary.todayIncidents.isEmpty {
                                Divider().padding(.vertical, FamSpacing.unit)
                                VStack(alignment: .leading, spacing: FamSpacing.xs) {
                                    ForEach(summary.todayIncidents) { incident in
                                        HStack(alignment: .top, spacing: FamSpacing.xs) {
                                            Circle()
                                                .fill(incident.severity == .info ? FamColor.primary : FamColor.warning)
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 6)
                                            Text(incident.summary ?? incident.eventType.label)
                                                .font(FamFont.body(14))
                                                .foregroundStyle(FamColor.foregroundMuted)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(FamSpacing.lg)
                        .background(FamColor.success.opacity(0.06), in: RoundedRectangle(cornerRadius: FamRadius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: FamRadius.card)
                                .stroke(FamColor.success.opacity(0.2), lineWidth: 1)
                        )
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(FamColor.warning)
                    }
                }
                .padding(FamSpacing.md)
            }
            .background(FamColor.background)
            .navigationTitle("Today")
            .refreshable { await viewModel.load() }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
