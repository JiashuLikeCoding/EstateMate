//
//  OpenHouseEventsView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import SwiftUI

struct OpenHouseEventsView: View {
    private let service = OpenHouseService()

    @State private var events: [OpenHouseEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var newTitle: String = ""

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section("Create") {
                TextField("Event title (e.g., 123 Main St – Feb 10)", text: $newTitle)
                Button("Create Event") {
                    Task { await createEvent() }
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }

            Section("Events") {
                if events.isEmpty {
                    Text("No events yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.title)
                                Text(e.isActive ? "Active" : "Inactive")
                                    .font(.caption)
                                    .foregroundStyle(e.isActive ? .green : .secondary)
                            }
                            Spacer()
                            if !e.isActive {
                                Button("Make Active") {
                                    Task { await makeActive(e) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Events")
        .overlay {
            if isLoading {
                ProgressView().controlSize(.large)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await service.listEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createEvent() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let created = try await service.createEvent(
                title: newTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                isActive: events.isEmpty
            )
            newTitle = ""
            // reload
            events = try await service.listEvents()
            if created.isActive == false, events.count == 1 {
                // noop
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeActive(_ event: OpenHouseEvent) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.setActive(eventId: event.id)
            events = try await service.listEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { OpenHouseEventsView() }
}
