//
//  WorkspacePickerView.swift
//  EstateMate
//
//  Created by OpenClaw on 2026-02-09.
//

import SwiftUI

struct WorkspacePickerView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackground()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("选择系统")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("如需切换，请退出登录后重新登录再选择。")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.72))
                    }

                    AuthCard {
                        ForEach(Workspace.allCases) { w in
                            Button {
                                sessionStore.selectedWorkspace = w
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.title)
                                            .font(.headline)
                                        Text(w.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)

                            if w != Workspace.allCases.last {
                                Divider().overlay(Color.white.opacity(0.12))
                            }
                        }

                        Button {
                            Task { await sessionStore.signOut() }
                        } label: {
                            Text("退出登录")
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 8)
                        .buttonStyle(SecondaryButtonStyle())
                        .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    WorkspacePickerView().environmentObject(SessionStore())
}
