//
//  FormBuilderLoadView.swift
//  EstateMate
//
//  Loads a form record by id before presenting the builder.
//  This avoids decoding failures in list screens (which may only fetch FormSummary).
//

import SwiftUI

struct FormBuilderLoadView: View {
    private let service = DynamicFormService()

    let formId: UUID

    @State private var form: FormRecord?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        EMScreen("表单设计") {
            if let form {
                FormBuilderAdaptiveView(form: form)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        ProgressView()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    Button("重试") {
                        Task { await load() }
                    }
                    .buttonStyle(EMPrimaryButtonStyle(disabled: false))
                }
                .padding(EMTheme.padding)
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            form = try await service.getForm(id: formId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
