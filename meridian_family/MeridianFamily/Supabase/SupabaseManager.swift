import Foundation
import Supabase

/// Reads client-side Supabase config (anon key only, never service-role)
/// from the app's Info.plist / build settings. Nothing is queryable until
/// a live Supabase project exists — see /meridian/frontendguytodo.md.
enum SupabaseConfig {
    static var url: URL {
        guard
            let string = Bundle.main.object(forInfoDictionaryKey: "MERIDIAN_SUPABASE_URL") as? String,
            let url = URL(string: string), !string.isEmpty
        else {
            return URL(string: "https://not-configured.supabase.co")!
        }
        return url
    }

    static var anonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "MERIDIAN_SUPABASE_ANON_KEY") as? String) ?? ""
    }

    static var isConfigured: Bool {
        !anonKey.isEmpty && url.host != "not-configured.supabase.co"
    }
}

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
