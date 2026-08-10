import Foundation
import Supabase

enum AssistanceActionError: LocalizedError {
    case notAuthorized
    case invalidTransition
    case notFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "You don't have permission to respond to this request."
        case .invalidTransition: return "That status change isn't valid anymore — someone may have already responded."
        case .notFound: return "This request couldn't be found — it may have already been resolved."
        case .unknown: return "Something went wrong. Try again."
        }
    }
}

/// RPC args for public.respond_to_assistance_request.
private struct RespondToAssistanceRequestArgs: Encodable {
    let pAssistanceRequestId: String
    let pNewStatus: String
    let pNote: String?

    enum CodingKeys: String, CodingKey {
        case pAssistanceRequestId = "p_assistance_request_id"
        case pNewStatus = "p_new_status"
        case pNote = "p_note"
    }
}

/// Single write path for assistance-request status — mirrors
/// IncidentActionService's shape and respond_to_assistance_request's error
/// codes (supabase/migrations, resident-initiated assistance path):
/// 42501 not authorized, 22023 invalid transition, P0002 not found.
enum AssistanceActionService {
    static func respond(
        assistanceRequestId: String,
        newStatus: AssistanceStatus,
        note: String? = nil
    ) async -> Result<Void, AssistanceActionError> {
        let args = RespondToAssistanceRequestArgs(
            pAssistanceRequestId: assistanceRequestId,
            pNewStatus: newStatus.rawValue,
            pNote: note?.isEmpty == false ? note : nil
        )
        do {
            try await SupabaseManager.client
                .rpc("respond_to_assistance_request", params: args)
                .execute()
            return .success(())
        } catch let error as PostgrestError {
            switch error.code {
            case "42501": return .failure(.notAuthorized)
            case "22023": return .failure(.invalidTransition)
            case "P0002": return .failure(.notFound)
            default: return .failure(.unknown)
            }
        } catch {
            return .failure(.unknown)
        }
    }
}
