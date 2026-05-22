//
//  SupabaseConfig.swift
//  AICampaignConsultant
//
//  Reads Supabase credentials from the auto-generated Config.swift, which
//  is regenerated at build time from the project's public environment
//  variables (EXPO_PUBLIC_SUPABASE_URL, EXPO_PUBLIC_SUPABASE_ANON_KEY).
//
//  Both values are PUBLIC (safe to ship): the URL is the project base URL
//  and the anon key is the public client key. Row-Level Security policies
//  on the candidate_profiles table protect data — see SupabaseClient.swift.
//

import Foundation

nonisolated enum SupabaseConfig {
    // Hardcoded fallbacks (both are PUBLIC client credentials — safe to ship).
    // Used when env-var injection is empty (e.g. Rork Supabase integration
    // not provisioned). The anon key is protected by Row-Level Security.
    private static let fallbackURL = "https://fsawsskwiplnbdwsnrvw.supabase.co"
    private static let fallbackAnonKey = "sb_publishable_kNVbdpo6nmEZ2f4L6LBHXQ_5d1-g9_g"

    /// e.g. "https://xxxxxxxx.supabase.co"
    static var url: String {
        let v = Config.allValues["EXPO_PUBLIC_SUPABASE_URL"] ?? ""
        return v.isEmpty ? fallbackURL : v
    }

    /// Supabase anon (public) key.
    static var anonKey: String {
        let v = Config.allValues["EXPO_PUBLIC_SUPABASE_ANON_KEY"] ?? ""
        return v.isEmpty ? fallbackAnonKey : v
    }
}
