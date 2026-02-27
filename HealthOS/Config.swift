import Foundation

/// App-level configuration values sourced from Info.plist,
/// which in turn reads from Config.xcconfig (not committed).
///
/// Setup: copy Config.xcconfig.template → Config.xcconfig and fill in values.
enum Config {
    static let supabaseURL: URL = {
        guard
            let raw = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
            !raw.isEmpty,
            !raw.hasPrefix("$"),
            let url = URL(string: raw)
        else {
            fatalError("SUPABASE_URL missing or invalid in Config.xcconfig")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard
            let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
            !key.isEmpty,
            !key.hasPrefix("$")
        else {
            fatalError("SUPABASE_ANON_KEY missing or invalid in Config.xcconfig")
        }
        return key
    }()
}
