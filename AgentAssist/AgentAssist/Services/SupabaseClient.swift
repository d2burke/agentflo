import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://giloreldlxdpqsvmqiqh.supabase.co")!
    static let anonKey = "sb_publishable_1QPOpHS5V-NG39-G3B1u8Q_MVIE-B9d"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
