import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        VStack(spacing: 0) {
            subTabs
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .background(
                    Rectangle()
                        .fill(Constants.VisualStyle.divider)
                        .frame(height: 0.5),
                    alignment: .bottom
                )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let bannerMessage = viewModel.bannerMessage {
                        SettingsBanner(message: bannerMessage)
                            .padding(.bottom, 12)
                    }

                    switch viewModel.settingsSection {
                    case .general:
                        GeneralSettingsSection(viewModel: viewModel)
                    case .backup:
                        BackupSettingsSection(viewModel: viewModel)
                    case .about:
                        AboutSettingsSection(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
        .background(Constants.VisualStyle.surface)
    }

    private var subTabs: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.section) { tab in
                subTabButton(title: tab.title, section: tab.section)
            }
            Spacer(minLength: 0)
        }
    }

    private var tabs: [(section: MainWindowViewModel.SettingsSection, title: String)] {
        [
            (.general, "通用"),
            (.backup, "备份与数据"),
            (.about, "关于")
        ]
    }

    private func subTabButton(title: String, section: MainWindowViewModel.SettingsSection) -> some View {
        let isActive = viewModel.settingsSection == section
        return Button {
            viewModel.settingsSection = section
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isActive ? Constants.VisualStyle.text : Constants.VisualStyle.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                Rectangle()
                    .fill(isActive ? Constants.VisualStyle.text : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared rows

struct SettingsBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Constants.VisualStyle.accent)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Constants.VisualStyle.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Constants.VisualStyle.accentDim)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Constants.VisualStyle.accentBorder, lineWidth: 0.5)
        )
    }
}

struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Constants.VisualStyle.textQuaternary)
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
    }
}

struct SettingsSectionContainer<Content: View>: View {
    let title: String
    let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionHeader(title: title)
            content()
        }
        .padding(.bottom, 28)
    }
}

struct SettingsRow<Control: View>: View {
    let label: String
    let hint: String?
    let control: Control

    init(label: String, hint: String? = nil, @ViewBuilder control: () -> Control) {
        self.label = label
        self.hint = hint
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Constants.VisualStyle.text)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 14)
        .overlay(
            Rectangle()
                .fill(Constants.VisualStyle.divider)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

struct SettingsPillButton: View {
    let title: String
    let systemImage: String?
    let tone: Tone
    let action: () -> Void

    enum Tone {
        case neutral
        case primary
        case danger
    }

    init(_ title: String, systemImage: String? = nil, tone: Tone = .neutral, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch tone {
        case .primary: return .white
        case .neutral: return Constants.VisualStyle.text
        case .danger: return Constants.VisualStyle.danger
        }
    }

    private var fillColor: Color {
        switch tone {
        case .primary: return Constants.VisualStyle.accent
        case .neutral: return Color.white.opacity(0.06)
        case .danger: return Color.clear
        }
    }

    private var borderColor: Color {
        switch tone {
        case .primary: return .clear
        case .neutral: return Constants.VisualStyle.border
        case .danger: return Constants.VisualStyle.danger.opacity(0.3)
        }
    }
}

// MARK: - General

private struct GeneralSettingsSection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionContainer("快捷键") {
                SettingsRow(
                    label: "呼出面板",
                    hint: "这是呼出快捷面板唯一的入口。"
                ) {
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                        .labelsHidden()
                }
            }

            SettingsSectionContainer("面板行为") {
                SettingsRow(
                    label: "固定面板",
                    hint: "关闭时面板失焦自动收起；开启后持续置顶，利于边看边选。"
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.isPanelPinned },
                        set: { viewModel.setPanelPinned($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            SettingsSectionContainer("权限与启动") {
                SettingsRow(
                    label: "辅助功能权限",
                    hint: "用于监听快捷键和自动粘贴。未授权时系统自动走仅复制兜底。"
                ) {
                    HStack(spacing: 8) {
                        permissionPill
                        SettingsPillButton("请求授权", systemImage: "hand.raised") {
                            viewModel.requestAccessibilityPermission()
                        }
                        SettingsPillButton("系统设置", systemImage: "arrow.up.forward") {
                            viewModel.openAccessibilitySettings()
                        }
                        SettingsPillButton("重新检测", systemImage: "arrow.clockwise") {
                            viewModel.refreshPermissionState()
                        }
                    }
                }

                SettingsRow(
                    label: "登录时启动",
                    hint: "系统启动时自动在后台运行。"
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.launchAtLoginEnabled },
                        set: { viewModel.setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }
        }
    }

    private var permissionPill: some View {
        let granted = viewModel.hasAccessibilityPermission
        let color: Color = granted ? Constants.VisualStyle.success : Constants.VisualStyle.warn
        let dim: Color = granted ? Constants.VisualStyle.successDim : Constants.VisualStyle.warnDim
        return HStack(spacing: 4) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(granted ? "已授权" : "未授权")
                .font(.system(size: 11.5, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(dim)
        )
    }
}

// MARK: - Backup

private struct BackupSettingsSection: View {
    @ObservedObject var viewModel: MainWindowViewModel
    @State private var pathDisclosure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionContainer("备份") {
                SettingsRow(
                    label: "自动备份",
                    hint: "每次启动时备份一次，最多保留 \(Constants.automaticBackupRetentionCount) 份。"
                ) {
                    Text("已启用")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Constants.VisualStyle.success)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Constants.VisualStyle.successDim)
                        )
                }
                SettingsRow(
                    label: "备份状态",
                    hint: backupStatusHint
                ) {
                    HStack(spacing: 6) {
                        SettingsPillButton("备份目录", systemImage: "folder") {
                            viewModel.openBackupDirectory()
                        }
                        SettingsPillButton("立即备份", systemImage: "plus", tone: .primary) {
                            viewModel.createBackupNow()
                        }
                    }
                }
            }

            SettingsSectionContainer("维护") {
                SettingsRow(
                    label: "刷新状态",
                    hint: "重新读取数据库和权限状态。"
                ) {
                    SettingsPillButton("刷新", systemImage: "arrow.clockwise") {
                        viewModel.refreshOperationalStatus()
                        viewModel.refreshUpdaterStatus()
                    }
                }
                SettingsRow(
                    label: "清理旧日志",
                    hint: "清理 30 天前的执行日志。"
                ) {
                    SettingsPillButton("清理", systemImage: "trash", tone: .danger) {
                        viewModel.cleanupLogs()
                    }
                }
            }

            SettingsSectionContainer("数据位置") {
                if let snapshot = viewModel.storageHealthSnapshot {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            pathDisclosure.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: pathDisclosure ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Constants.VisualStyle.textTertiary)
                                Text("文件路径")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Constants.VisualStyle.text)
                                Text("落盘、备份、恢复隔离目录")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Constants.VisualStyle.textQuaternary)
                                Spacer(minLength: 0)
                                Text(pathDisclosure ? "收起" : "展开")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Constants.VisualStyle.textQuaternary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if pathDisclosure {
                            VStack(alignment: .leading, spacing: 10) {
                                pathRow(title: "数据库", value: snapshot.databaseURL.path)
                                pathRow(title: "备份", value: snapshot.backupDirectoryURL.path)
                                pathRow(title: "恢复隔离", value: snapshot.recoveryDirectoryURL.path)
                                pathRow(title: "日志", value: snapshot.logsDirectoryURL.path)
                                if let backup = snapshot.latestBackupURL {
                                    pathRow(title: "最近备份", value: backup.lastPathComponent)
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 14)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Constants.VisualStyle.border, lineWidth: 0.5)
                    )
                } else {
                    Text("尚未加载数据目录信息。")
                        .font(.system(size: 12))
                        .foregroundStyle(Constants.VisualStyle.textSecondary)
                }
            }
        }
    }

    private var backupStatusHint: String {
        guard let snapshot = viewModel.storageHealthSnapshot else {
            return "尚未加载备份信息。"
        }
        let backupCount = snapshot.backupCount
        let max = Constants.automaticBackupRetentionCount
        let latest: String = {
            guard let url = snapshot.latestBackupURL,
                  let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                return "未知时间"
            }
            return modifiedAt.formatted(date: .abbreviated, time: .shortened)
        }()
        return "当前已保存 \(backupCount) / \(max) 份，最近一次：\(latest)。"
    }

    private func pathRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5))
                .tracking(0.5)
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
                Button {
                    copyPath(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("复制路径")
            }
        }
    }

    private func copyPath(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }
}

// MARK: - About

private struct AboutSettingsSection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSectionContainer("版本") {
                SettingsRow(
                    label: "当前版本",
                    hint: "PromptPanel \(appVersionText)"
                ) {
                    Text(appVersionText)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Constants.VisualStyle.textSecondary)
                }
                SettingsRow(
                    label: "自动更新",
                    hint: viewModel.updaterStatusMessage
                ) {
                    SettingsPillButton("检查更新", systemImage: "arrow.down.circle") {
                        viewModel.checkForUpdates()
                    }
                }
            }

            SettingsSectionContainer("运行日志") {
                if let summary = viewModel.executionHealthSummary {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            summaryPill(title: "近 7 天执行", value: "\(summary.totalCount)", tone: .neutral)
                            summaryPill(title: "成功", value: "\(summary.successCount)", tone: .success)
                            summaryPill(title: "复制兜底", value: "\(summary.clipboardOnlyCount)", tone: .warn)
                            summaryPill(title: "失败", value: "\(summary.failedCount)", tone: .danger)
                        }
                        SettingsRow(label: "最近执行") {
                            Text(format(date: summary.latestExecutionAt))
                                .font(.system(size: 12))
                                .foregroundStyle(Constants.VisualStyle.textSecondary)
                        }
                        SettingsRow(label: "最近异常") {
                            Text(format(date: summary.latestFailureAt))
                                .font(.system(size: 12))
                                .foregroundStyle(Constants.VisualStyle.textSecondary)
                        }
                    }
                } else {
                    Text("最近 7 天还没有执行记录。")
                        .font(.system(size: 12))
                        .foregroundStyle(Constants.VisualStyle.textSecondary)
                }
            }

            SettingsSectionContainer("最近执行记录") {
                if viewModel.recentExecutionLogs.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(Constants.VisualStyle.textTertiary)
                        Text("当前还没有执行记录。按下全局快捷键选一条词条后，这里会立即出现。")
                            .font(.system(size: 12))
                            .foregroundStyle(Constants.VisualStyle.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 16)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.recentExecutionLogs.prefix(8)) { log in
                            ExecutionLogRow(log: log, projectName: viewModel.projectName(for: log.projectId))
                        }
                    }
                }
            }
        }
    }

    private enum PillTone {
        case neutral
        case success
        case warn
        case danger
    }

    private func summaryPill(title: String, value: String, tone: PillTone) -> some View {
        let color: Color = {
            switch tone {
            case .neutral: return Constants.VisualStyle.accent
            case .success: return Constants.VisualStyle.success
            case .warn: return Constants.VisualStyle.warn
            case .danger: return Constants.VisualStyle.danger
            }
        }()
        return VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Constants.VisualStyle.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.22), lineWidth: 0.5)
        )
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        return "\(shortVersion) (\(buildVersion))"
    }

    private func format(date: Date?) -> String {
        guard let date else {
            return "暂无"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct ExecutionLogRow: View {
    let log: ExecutionLog
    let projectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(resultTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(resultColor)
                Text(projectName)
                    .font(.system(size: 11))
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
                Spacer(minLength: 0)
                Text(log.createdAt.formatted(date: .abbreviated, time: .standard))
                    .font(.system(size: 11))
                    .foregroundStyle(Constants.VisualStyle.textTertiary)
            }
            HStack(spacing: 10) {
                infoPill(title: "目标应用", value: log.frontAppBundleId ?? "未知")
                if let durationText {
                    infoPill(title: "耗时", value: durationText)
                }
                infoPill(title: "权限", value: log.hasAccessibility ? "已授权" : "未授权")
                infoPill(title: "自动粘贴", value: log.pasteAttempted ? (log.pasteSuccess ? "成功" : "失败") : "未尝试")
                Spacer(minLength: 0)
            }
            if let failureReasonTitle {
                infoPill(title: "失败原因", value: failureReasonTitle)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Constants.VisualStyle.border, lineWidth: 0.5)
        )
    }

    private var resultTitle: String {
        switch log.result {
        case Constants.ExecutionResult.success.rawValue: return "执行成功"
        case Constants.ExecutionResult.clipboardOnly.rawValue: return "复制兜底"
        default: return "执行失败"
        }
    }

    private var resultColor: Color {
        switch log.result {
        case Constants.ExecutionResult.success.rawValue: return Constants.VisualStyle.success
        case Constants.ExecutionResult.clipboardOnly.rawValue: return Constants.VisualStyle.warn
        default: return Constants.VisualStyle.danger
        }
    }

    private var durationText: String? {
        guard let totalDurationMs = log.totalDurationMs else {
            return nil
        }
        return "\(totalDurationMs) ms"
    }

    private var failureReasonTitle: String? {
        guard let failureReason = log.failureReason else {
            return nil
        }
        switch failureReason {
        case Constants.ExecutionFailureReason.clipboardWriteFailed.rawValue: return "剪贴板写入失败"
        case Constants.ExecutionFailureReason.accessibilityNotGranted.rawValue: return "辅助功能权限未授权"
        case Constants.ExecutionFailureReason.targetAppNotRestored.rawValue: return "原目标应用未恢复前台"
        case Constants.ExecutionFailureReason.pasteEventCreationFailed.rawValue: return "自动粘贴事件创建失败"
        default: return "未分类"
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(Constants.VisualStyle.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.04)))
    }
}
