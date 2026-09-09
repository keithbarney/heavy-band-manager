import Foundation
import Supabase

enum Config {
#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
    // Hard isolation: even unhandled actions cannot reach a production backend.
    static let supabase = SupabaseClient(supabaseURL: URL(string: "http://127.0.0.1:1")!, supabaseKey: "native-ui-preview")
#else
    static let supabase = SupabaseClient(
        supabaseURL: URL(string: Secrets.supabaseURL)!,
        supabaseKey: Secrets.supabaseAnonKey,
        options: .init(
            auth: .init(
                storage: UserDefaultsLocalStorage()
            )
        )
    )
#endif
}

/// Persists Supabase auth tokens in UserDefaults so sessions survive app restarts.
/// For production, migrate to Keychain. Sufficient for dev/testing.
final class UserDefaultsLocalStorage: AuthLocalStorage, Sendable {
    private let defaults = UserDefaults.standard
    private let prefix = "supabase.auth."

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: prefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: prefix + key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: prefix + key)
    }
}
