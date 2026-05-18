import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://bvgswlacgejikbuuwnpy.supabase.co")!
    static let publishableKey = "sb_publishable_ic3UNeB8Vd1fiFs6z49Ceg_pFMaY8Ga"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.publishableKey,
    options: .init(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)
