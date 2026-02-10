//
//  WorkspacePickerView.swift
//  EstateMate
//

import SwiftUI

struct WorkspacePickerView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            EMScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        EMSectionHeader("选择系统", subtitle: "选择要进入的模块")

                        EMCard {
                            ForEach(Workspace.allCases) { w in
                                Button {
                                    sessionStore.selectedWorkspace = w
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(w.title)
                                                .font(.headline)
                                            Text(w.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(EMTheme.ink2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(EMTheme.ink2)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)

                                if w != Workspace.allCases.last {
                                    Divider().overlay(EMTheme.line)
                                }
                            }
                        }

                        Button {
                            Task { await sessionStore.signOut() }
                        } label: {
                            Text("退出登录")
                        }
                        .buttonStyle(EMDangerButtonStyle())
                    }
                    .padding(EMTheme.padding)
                }
            }
        }
    }
}

#Preview {
    WorkspacePickerView().environmentObject(SessionStore())
}
