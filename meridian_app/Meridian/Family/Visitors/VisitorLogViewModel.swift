import Foundation
import Supabase

@MainActor
final class VisitorLogViewModel: ObservableObject {
    @Published private(set) var visitors: [FamilyVisitorRow] = []
    @Published var errorMessage: String?
    private var pollTask: Task<Void, Never>?

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    var todayCount: Int {
        visitors.filter { Calendar.current.isDateInToday($0.detectedAt) }.count
    }

    func load() async {
        do {
            // An empty result is expected/valid (no active family_visibility
            // consent yet), not an error — api-contract.md.
            let rows: [FamilyVisitorRow] = try await SupabaseManager.client
                .from("family_visitor_feed")
                .select()
                .order("detected_at", ascending: false)
                .execute()
                .value
            visitors = rows
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load the visitor log."
        }
    }
}
