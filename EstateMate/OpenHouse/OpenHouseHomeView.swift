//
//  OpenHouseHomeView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import SwiftUI

struct OpenHouseHomeView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("OpenHouse Events") {
                        OpenHouseEventsView()
                    }

                    NavigationLink("Start Guest Mode") {
                        OpenHouseGuestModeView()
                    }
                }

                Section {
                    Button("Sign out") {
                        Task { await sessionStore.signOut() }
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("OpenHouse")
        }
    }
}

#Preview {
    OpenHouseHomeView().environmentObject(SessionStore())
}
