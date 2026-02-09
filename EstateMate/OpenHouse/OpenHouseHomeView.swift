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
                Section("Dynamic Forms (MVP)") {
                    NavigationLink("Events") {
                        OpenHouseEventsV2View()
                    }

                    NavigationLink("Start Guest Mode") {
                        OpenHouseGuestModeV2View()
                    }

                    NavigationLink("Form Builder") {
                        FormBuilderView()
                    }
                }

                Section("Legacy (fixed fields)") {
                    NavigationLink("Events (legacy)") {
                        OpenHouseEventsView()
                    }

                    NavigationLink("Guest Mode (legacy)") {
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
