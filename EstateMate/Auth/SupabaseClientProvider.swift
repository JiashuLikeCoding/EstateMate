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
        supabaseKey: "sb_publishable_1bF-CN3xTNg5z9MdzKvh1A_MuTRrRFo"
    )
}
