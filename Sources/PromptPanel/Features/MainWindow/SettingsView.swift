import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MainWindowViewModel

    private let contentMaxWidth: CGFloat = 980
    private let columnSpacing: CGFloat = 12

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let bannerMessage = viewModel.bannerMessage {
                    SettingsBanner(message: bannerMessage)
                }

                HStack(alignment: .top, spacing: columnSpacing) {
                    SettingsColumn {
                        HotkeySection(viewModel: viewModel)
                        PanelBehaviorSection(viewModel: viewModel)
                        PermissionSection(viewModel: viewModel)
                    }

                    SettingsColumn {
                        OperationOverviewSection(viewModel: viewModel)
                        MaintenanceSection(viewModel: viewModel)
                    }
                }

                DataLocationSection(viewModel: viewModel)

                RecentExecutionsSection(viewModel: viewModel)
            }
            .frame(maxWidth: contentMaxWidth, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .background(Constants.VisualStyle.surface)
    }
}

// MARK: - Shared primitives

private struct SettingsColumn<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(title: title)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Constants.VisualStyle.border, lineWidth: 0.5)
        )
    }
}

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
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Constants.VisualStyle.text)
    }
}

struct SettingsRow<Control: View>: View {
    let label: String
    let hint: String?
    let control: Control
    let dense: Bool

    init(label: String, hint: String? = nil, dense: Bool = false, @ViewBuilder control: () -> Control) {
        self.label = label
        self.hint = hint
        self.dense = dense
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Constants.VisualStyle.text)
                if let hint {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 10)
            control
        }
        .padding(.vertical, dense ? 6 : 10)
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
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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

// MARK: - Left column sections

private struct HotkeySection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        SettingsCard("快捷键") {
            SettingsRow(
                label: "呼出面板",
                hint: "这是呼出快捷面板唯一的入口。"
            ) {
                KeyboardShortcuts.Recorder(for: .togglePanel)
                    .labelsHidden()
            }
        }
    }
}

private struct PanelBehaviorSection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        SettingsCard("面板行为") {
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
            SettingsRow(
                label: "显示键位提示栏",
                hint: "面板底部显示 ⏎ / ⌘C / ⌘1-9 等提示。熟练后可关闭。"
            ) {
                Toggle("", isOn: Binding(
                    get: { viewModel.panelShowFooter },
                    set: { viewModel.setPanelShowFooter($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
            SettingsRow(
                label: "紧凑行高",
                hint: "每行更紧凑，一屏可见更多词条。"
            ) {
                Toggle("", isOn: Binding(
                    get: { viewModel.panelCompactRows },
                    set: { viewModel.setPanelCompactRows($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
        }
    }
}

private struct PermissionSection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        SettingsCard("权限与启动") {
            SettingsRow(
                label: "辅助功能权限",
                hint: "用于监听快捷键和自动粘贴；未授权时自动走仅复制兜底。"
            ) {
                permissionPill
            }
            SettingsRow(
                label: "授权操作",
                hint: "如需重新授权，请先从系统设置里关闭再重开。"
            ) {
                HStack(spacing: 6) {
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

// MARK: - Right column sections

private struct OperationOverviewSection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        SettingsCard("运行概况") {
            SettingsRow(label: "当前版本", dense: true) {
                valueText(appVersionText, monospaced: true)
            }
            SettingsRow(label: "更新状态", dense: true) {
                Text(viewModel.updaterStatusMessage)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 240, alignment: .trailing)
            }

            if let snapshot = viewModel.storageHealthSnapshot {
                SettingsRow(label: "数据大小", dense: true) {
                    valueText(ByteCountFormatter.string(fromByteCount: snapshot.databaseSizeBytes, countStyle: .file))
                }
                SettingsRow(label: "备份数量", dense: true) {
                    valueText("\(snapshot.backupCount) / \(Constants.automaticBackupRetentionCount)")
                }
                SettingsRow(label: "最近备份", dense: true) {
                    valueText(latestBackupSummary(snapshot.latestBackupURL))
                }
            }

            if let summary = viewModel.executionHealthSummary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("近 7 天执行")
                        .font(.system(size: 11))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                    HStack(spacing: 6) {
                        summaryPill(title: "执行", value: "\(summary.totalCount)", tone: .neutral)
                        summaryPill(title: "成功", value: "\(summary.successCount)", tone: .success)
                        summaryPill(title: "复制兜底", value: "\(summary.clipboardOnlyCount)", tone: .warn)
                        summaryPill(title: "失败", value: "\(summary.failedCount)", tone: .danger)
                    }
                }
                .padding(.vertical, 10)
                .overlay(
                    Rectangle()
                        .fill(Constants.VisualStyle.divider)
                        .frame(height: 0.5),
                    alignment: .bottom
                )

                SettingsRow(label: "最近执行", dense: true) {
                    valueText(format(date: summary.latestExecutionAt))
                }
                SettingsRow(label: "最近异常", dense: true) {
                    valueText(format(date: summary.latestFailureAt))
                }
            } else {
                Text("最近 7 天还没有执行记录。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Constants.VisualStyle.textTertiary)
                    .padding(.vertical, 10)
            }
        }
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        return "\(shortVersion) (\(buildVersion))"
    }

    private func valueText(_ value: String, monospaced: Bool = false) -> some View {
        Text(value)
            .font(.system(size: 11.5, weight: .medium, design: monospaced ? .monospaced : .default))
            .foregroundStyle(Constants.VisualStyle.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private func latestBackupSummary(_ url: URL?) -> String {
        guard let url,
              let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return "暂无"
        }
        return modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func format(date: Date?) -> String {
        guard let date else { return "暂无" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private enum PillTone {
        case neutral, success, warn, danger
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
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Constants.VisualStyle.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(color.opacity(0.22), lineWidth: 0.5)
        )
    }
}

private struct MaintenanceSection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        SettingsCard("维护操作") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ],
                alignment: .leading,
                spacing: 6
            ) {
                SettingsPillButton("刷新状态", systemImage: "arrow.clockwise") {
                    viewModel.refreshOperationalStatus()
                    viewModel.refreshUpdaterStatus()
                }
                SettingsPillButton("检查更新", systemImage: "arrow.down.circle") {
                    viewModel.checkForUpdates()
                }
                SettingsPillButton("立即备份", systemImage: "plus", tone: .primary) {
                    viewModel.createBackupNow()
                }
                SettingsPillButton("数据目录", systemImage: "folder") {
                    viewModel.openDataDirectory()
                }
                SettingsPillButton("备份目录", systemImage: "tray.full") {
                    viewModel.openBackupDirectory()
                }
                SettingsPillButton("清理日志", systemImage: "trash", tone: .danger) {
                    viewModel.cleanupLogs()
                }
            }
            .padding(.vertical, 6)

            Text("Sparkle 只在 feed 和公钥都配置完成后启用；其余情况下沿用本地打包与备份恢复链路。")
                .font(.system(size: 11))
                .foregroundStyle(Constants.VisualStyle.textTertiary)
                .padding(.top, 4)
        }
    }
}

// MARK: - Bottom full-width sections

private struct DataLocationSection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        SettingsCard("数据位置") {
            if let snapshot = viewModel.storageHealthSnapshot {
                Text("落盘路径、备份和恢复隔离目录。复制路径可直接粘贴到终端。")
                    .font(.system(size: 11))
                    .foregroundStyle(Constants.VisualStyle.textTertiary)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 10) {
                    pathRow(title: "数据库", value: snapshot.databaseURL.path)
                    pathRow(title: "备份目录", value: snapshot.backupDirectoryURL.path)
                    pathRow(title: "恢复隔离", value: snapshot.recoveryDirectoryURL.path)
                    pathRow(title: "日志目录", value: snapshot.logsDirectoryURL.path)
                    if let url = snapshot.latestBackupURL {
                        pathRow(title: "最近备份文件", value: url.lastPathComponent)
                    }
                }
            } else {
                Text("尚未加载数据目录信息。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Constants.VisualStyle.textTertiary)
            }
        }
    }

    private func pathRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5))
                .tracking(0.3)
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
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

private struct RecentExecutionsSection: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        SettingsCard("最近执行记录") {
            if viewModel.recentExecutionLogs.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                    Text("当前还没有执行记录。按下全局快捷键选一条词条后，这里会立即出现。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Constants.VisualStyle.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.recentExecutionLogs.prefix(6)) { log in
                        ExecutionLogRow(log: log, projectName: viewModel.projectName(for: log.projectId))
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

private struct ExecutionLogRow: View {
    let log: ExecutionLog
    let projectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(resultTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(resultColor)
                Text(projectName)
                    .font(.system(size: 11))
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
                Spacer(minLength: 0)
                Text(log.createdAt.formatted(date: .abbreviated, time: .standard))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Constants.VisualStyle.textTertiary)
            }
            HStack(spacing: 8) {
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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
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
        guard let totalDurationMs = log.totalDurationMs else { return nil }
        return "\(totalDurationMs) ms"
    }

    private var failureReasonTitle: String? {
        guard let failureReason = log.failureReason else { return nil }
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
                .font(.system(size: 9.5))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
            Text(value)
                .font(.system(size: 10.5))
                .foregroundStyle(Constants.VisualStyle.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.04)))
    }
}
