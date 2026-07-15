import SwiftUI

struct ResidentProfilesView: View {
    @StateObject private var viewModel: ResidentProfilesViewModel

    init(facilityId: String) {
        _viewModel = StateObject(wrappedValue: ResidentProfilesViewModel(facilityId: facilityId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.residents.isEmpty {
                    ContentUnavailableView("No residents yet", systemImage: "person.2")
                } else {
                    List(viewModel.residents) { resident in
                        VStack(alignment: .leading, spacing: MeridianSpacing.unit) {
                            Text(resident.displayName)
                                .font(MeridianFont.bodyMedium(17))
                            Text(resident.roomId ?? "Room unassigned")
                                .font(.footnote)
                                .foregroundStyle(MeridianColor.foregroundMuted)
                            if !resident.riskFlags.isEmpty {
                                HStack(spacing: MeridianSpacing.unit) {
                                    ForEach(resident.riskFlags, id: \.self) { flag in
                                        Text(flag.replacingOccurrences(of: "_", with: " "))
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(MeridianColor.muted, in: Capsule())
                                    }
                                }
                            }
                            if let notes = resident.careNotes {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundStyle(MeridianColor.foregroundMuted)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, MeridianSpacing.unit)
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.load() }
                }
            }
            .navigationTitle("Residents")
        }
        .task { await viewModel.load() }
    }
}
