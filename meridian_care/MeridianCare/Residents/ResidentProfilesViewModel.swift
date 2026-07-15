import Foundation
import Supabase

@MainActor
final class ResidentProfilesViewModel: ObservableObject {
    @Published private(set) var residents: [ResidentProfile] = []
    @Published var errorMessage: String?
    private let facilityId: String

    init(facilityId: String) {
        self.facilityId = facilityId
    }

    func load() async {
        do {
            let rows: [ResidentProfile] = try await SupabaseManager.client
                .from("resident_profiles")
                .select()
                .eq("facility_id", value: facilityId)
                .order("display_name", ascending: true)
                .execute()
                .value
            residents = rows
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load resident profiles."
        }
    }
}
