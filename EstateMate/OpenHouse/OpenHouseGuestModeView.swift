//
//  OpenHouseGuestModeView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import SwiftUI

struct OpenHouseGuestModeView: View {
    private let service = OpenHouseService()

    @State private var activeEvent: OpenHouseEvent?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    @State private var submittedCount = 0

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView().controlSize(.large)
            }

            if let activeEvent {
                Text(activeEvent.title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Form {
                    Section("Guest info") {
                        TextField("Full name", text: $fullName)
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...8)
                    }

                    Section {
                        Button("Submit") {
                            Task { await submit(activeEvent) }
                        }
                        .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

                        if submittedCount > 0 {
                            Text("Submitted: \(submittedCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No active event")
                        .font(.title3.bold())
                    Text("Create an event and set it active in the Events screen.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    NavigationLink("Go to Events") {
                        OpenHouseEventsView()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Guest Mode")
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reload") { Task { await load() } }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            activeEvent = try await service.getActiveEvent()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit(_ event: OpenHouseEvent) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = OpenHouseSubmissionInsert(
                eventId: event.id,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            _ = try await service.createSubmission(payload)
            submittedCount += 1

            // Clear for next guest
            fullName = ""
            phone = ""
            email = ""
            notes = ""

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { OpenHouseGuestModeView() }
}
