//
//  ContentView.swift
//  EstateMate
//
//  Created by Jason Li on 2026-02-09.
//

import SwiftUI

/// Legacy placeholder view. App entry now uses RootView.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView().environmentObject(SessionStore())
}
