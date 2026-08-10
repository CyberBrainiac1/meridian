import Foundation
import Supabase

enum ActivityActionError: LocalizedError {
    case notAuthorized
    case invalidStatus
    case notFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "You don't have permission to record activities."
        case .invalidStatus: return "That isn't a valid outcome for this activity."
        case .notFound: return "This activity is no longer on the resident's schedule."
        case .unknown: return "Something went wrong. Try again."
        }
    }
}

private struct RecordActivityCompletionArgs: Encodable {
    let pActivityId: String
    let pScheduledFor: String
    let pStatus: String
    let pNote: String?

    enum CodingKeys: String, CodingKey {
        case pActivityId = "p_activity_id"
        case pScheduledFor = "p_scheduled_for"
        case pStatus = "p_status"
        case pNote = "p_note"
    }
}

/// Single write path for activity completion — mirrors
/// record_activity_completion's error codes. Every surface that records an
/// activity (resident detail screen, notification action) goes through here,
/// so the schedule never diverges depending on where the caregiver tapped.
enum ActivityActionService {
    static func record(
        activityId: String,
        scheduledFor: Date,
        status: ActivityCompletionStatus,
        note: String? = nil
    ) async -> Result<Void, ActivityActionError> {
        // 'outstanding' is a derived display state, never something we write:
        // the absence of a row is what makes an activity outstanding.
        guard status != .outstanding else { return .failure(.invalidStatus) }

        let args = RecordActivityCompletionArgs(
            pActivityId: activityId,
            pScheduledFor: ISO8601DateFormatter().string(from: scheduledFor),
            pStatus: status.rawValue,
            pNote: note?.isEmpty == false ? note : nil
        )
        do {
            try await SupabaseManager.client
                .rpc("record_activity_completion", params: args)
                .execute()
            return .success(())
        } catch let error as PostgrestError {
            switch error.code {
            case "42501": return .failure(.notAuthorized)
            case "22023": return .failure(.invalidStatus)
            case "P0002": return .failure(.notFound)
            default: return .failure(.unknown)
            }
        } catch {
            return .failure(.unknown)
        }
    }
}
