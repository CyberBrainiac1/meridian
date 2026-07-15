import Foundation
import Supabase

enum IncidentActionError: LocalizedError {
    case notAuthorized
    case invalidTransition
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "You don't have permission to respond to this incident."
        case .invalidTransition: return "That status change isn't valid anymore — someone may have already responded."
        case .unknown: return "Something went wrong. Try again."
        }
    }
}

/// Single write path for incident status — mirrors respond_to_incident's
/// error codes (supabase/migrations/20260703000100_incident_rpc_and_views.sql).
/// This also feeds the response-time metric on Insights, so it's the only
/// place Care should ever change an incident's status.
enum IncidentActionService {
    static func respond(
        incidentId: String,
        newStatus: IncidentStatus,
        note: String? = nil
    ) async -> Result<Void, IncidentActionError> {
        let args = RespondToIncidentArgs(
            pIncidentId: incidentId,
            pNewStatus: newStatus.rawValue,
            pNote: note?.isEmpty == false ? note : nil
        )
        do {
            try await SupabaseManager.client
                .rpc("respond_to_incident", params: args)
                .execute()
            return .success(())
        } catch let error as PostgrestError {
            switch error.code {
            case "42501": return .failure(.notAuthorized)
            case "22023": return .failure(.invalidTransition)
            default: return .failure(.unknown)
            }
        } catch {
            return .failure(.unknown)
        }
    }
}
