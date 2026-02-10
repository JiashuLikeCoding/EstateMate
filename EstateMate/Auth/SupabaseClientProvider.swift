//
//  SupabaseClientProvider.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import Foundation
import Supabase

enum SupabaseClientProvider {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://hjjchvllpfvztcqbztcs.supabase.co")!,
        // Use the legacy anon key (JWT) for full compatibility with all Supabase endpoints.
        // Note: publishable keys may fail for certain endpoints (e.g. Edge Functions) with Invalid JWT.
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqamNodmxscGZ2enRjcWJ6dGNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NTg4NDAsImV4cCI6MjA4NjIzNDg0MH0.-6-mw5txgGuQyTAr9mV7k8lmfB08TZHF7rARlcETVIw"
    )
}
