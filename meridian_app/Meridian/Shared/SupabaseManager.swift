import Foundation
import Supabase

/// Reads client-side Supabase config (anon key only, never service-role) from
/// the app's Info.plist, which XcodeGen populates from Config/Secrets.xcconfig.
/// That file is gitignored — a fresh clone must supply its own before the app
/// can reach anything.
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
