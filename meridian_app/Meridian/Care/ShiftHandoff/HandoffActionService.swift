import Foundation
import Supabase

enum HandoffActionError: LocalizedError {
    case notAuthorized
    case noteNotFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "You don't have permission to acknowledge this note."
        case .noteNotFound: return "That note is no longer on the board — pull to refresh."
        case .unknown: return "Something went wrong. Try again."
        }
    }
}

/// RPC args for public.acknowledge_handoff_note. Declared here rather than in
/// Domain/Types.swift so the handoff feature stays self-contained, matching the
/// way IncidentActionService owns its own call site.
struct AcknowledgeHandoffNoteArgs: Encodable {
    let pNoteId: String

    enum CodingKeys: String, CodingKey {
        case pNoteId = "p_note_id"
    }
}

/// Single write path for handoff-note acknowledgement — mirrors
/// acknowledge_handoff_note's error codes. Acknowledging a note that someone
/// else already acknowledged is a no-op server-side, so it returns .success
/// here too: the caregiver re-reads the board and sees the existing check mark
/// rather than an error for something that is already true.
enum HandoffActionService {
    static func acknowledge(noteId: String) async -> Result<Void, HandoffActionError> {
        let args = AcknowledgeHandoffNoteArgs(pNoteId: noteId)
        do {
            try await SupabaseManager.client
                .rpc("acknowledge_handoff_note", params: args)
                .execute()
            return .success(())
        } catch let error as PostgrestError {
            switch error.code {
            case "42501": return .failure(.notAuthorized)
            case "P0002": return .failure(.noteNotFound)
            default: return .failure(.unknown)
            }
        } catch {
            return .failure(.unknown)
        }
    }
}
