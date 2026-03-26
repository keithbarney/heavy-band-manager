import Foundation
import Supabase

enum Config {
    static let supabase = SupabaseClient(
        supabaseURL: URL(string: Secrets.supabaseURL)!,
        supabaseKey: Secrets.supabaseAnonKey
    )
}
