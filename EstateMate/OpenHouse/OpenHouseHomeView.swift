//
//  OpenHouseHomeView.swift
//  EstateMate
//

import SwiftUI

struct OpenHouseHomeView: View {
    @EnvironmentObject var sessionStore: SessionStore

    private let service = OpenHouseService()

    @State private var lockResult: OpenHouseLockClaimResult?
    @State private var lockError: String?
    @State private var isCheckingLock: Bool = true

    private var isLockedByOtherDevice: Bool {
        guard let lockResult else { return false }
        return lockResult.isInUseByOtherDevice
    }

    var body: some View {
        NavigationStack {
            EMScreen {
                Group {
                    if isCheckingLock {
                        ProgressView("正在进入开放日系统…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else if isLockedByOtherDevice {
                        lockBlockedView
                    } else if let lockError {
                        errorView(lockError)
                    } else {
                        content
                    }
                }
                .padding(EMTheme.padding)
            }
        }
        .task {
            await claimLock(force: false)
        }
        .task(id: isLockedByOtherDevice) {
            // Heartbeat: keep lock alive (only when we successfully hold it)
            // Also: detect being taken over by another device and immediately block.
            guard isLockedByOtherDevice == false, lockError == nil, isCheckingLock == false else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                if let result = try? await service.claimOpenHouseLock(force: false) {
                    lockResult = result
                }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EMSectionHeader("开放日", subtitle: "创建表单、创建活动、开始现场填写")

                EMCard {
                    Text("活动")
                        .font(.headline)

                    NavigationLink {
                        OpenHouseEventHubView(initialTab: .create)
                    } label: {
                        row(title: "新建活动", subtitle: "创建活动并绑定表单")
                    }

                    Divider().overlay(EMTheme.line)

                    NavigationLink {
                        OpenHouseEventHubView(initialTab: .list)
                    } label: {
                        row(title: "活动列表", subtitle: "查看并启用活动")
                    }
                }

                EMCard {
                    Text("表单")
                        .font(.headline)

                    NavigationLink {
                        OpenHouseFormsView()
                    } label: {
                        row(title: "表单管理", subtitle: "查看与管理已创建的表单")
                    }

                    Divider().overlay(EMTheme.line)

                    NavigationLink {
                        FormBuilderAdaptiveView()
                    } label: {
                        row(title: "表单设计", subtitle: "创建新表单")
                    }
                }

                NavigationLink {
                    OpenHouseStartActivityView()
                } label: {
                    Text("准备开始活动")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EMPrimaryButtonStyle(disabled: false))

                Button {
                    Task { await sessionStore.signOut() }
                } label: {
                    Text("退出登录")
                }
                .buttonStyle(EMDangerButtonStyle())
            }
        }
    }

    private var lockBlockedView: some View {
        VStack(alignment: .leading, spacing: 14) {
            EMSectionHeader("无法进入开放日", subtitle: "此账号正在另一台设备使用开放日系统")

            EMCard {
                VStack(alignment: .leading, spacing: 8) {
                    if let name = lockResult?.existingDeviceName, !name.isEmpty {
                        Text("占用设备：\(name)")
                            .font(.subheadline)
                    }
                    Text("你可以选择等待对方退出/离线，或强制接管（对方会在下一次操作时被提示已被接管）。")
                        .font(.caption)
                        .foregroundStyle(EMTheme.ink2)
                }
            }

            Button {
                Task { await claimLock(force: false) }
            } label: {
                Text("刷新")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EMSecondaryButtonStyle())

            Button {
                Task { await claimLock(force: true) }
            } label: {
                Text("强制接管")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EMPrimaryButtonStyle(disabled: false))

            Button {
                sessionStore.selectedWorkspace = nil
            } label: {
                Text("返回")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EMGhostButtonStyle())

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            EMSectionHeader("进入失败", subtitle: "开放日系统锁定校验失败")

            EMCard {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(EMTheme.ink2)
            }

            Button {
                Task { await claimLock(force: false) }
            } label: {
                Text("重试")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EMPrimaryButtonStyle(disabled: false))

            Button {
                sessionStore.selectedWorkspace = nil
            } label: {
                Text("返回")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EMGhostButtonStyle())

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func claimLock(force: Bool) async {
        isCheckingLock = true
        lockError = nil
        do {
            let result = try await service.claimOpenHouseLock(force: force)
            lockResult = result
        } catch {
            lockError = error.localizedDescription
        }
        isCheckingLock = false
    }

    private func row(title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
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
}

#Preview {
    OpenHouseHomeView().environmentObject(SessionStore())
}
