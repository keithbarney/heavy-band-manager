import Foundation
import Supabase

enum Config {
    static let supabase = SupabaseClient(
        supabaseURL: URL(string: Secrets.supabaseURL)!,
        supabaseKey: Secrets.supabaseAnonKey,
        options: .init(
            auth: .init(
                storage: UserDefaultsLocalStorage()
            )
        )
    )
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
