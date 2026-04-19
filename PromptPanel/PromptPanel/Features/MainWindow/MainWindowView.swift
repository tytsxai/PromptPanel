import KeyboardShortcuts
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        TabView {
            libraryTab
                .tabItem {
                    Label("内容库", systemImage: "books.vertical")
                }

            settingsTab
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .frame(minWidth: 1080, minHeight: 720)
        .onAppear {
            viewModel.load()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.projectDraft != nil },
            set: { if !$0 { viewModel.projectDraft = nil } }
        )) {
            if let draftBinding = projectDraftBinding {
                ProjectEditorSheet(
                    draft: draftBinding,
                    onSave: viewModel.saveProjectDraft
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.entryDraft != nil },
            set: { if !$0 { viewModel.entryDraft = nil } }
        )) {
            if let draftBinding = entryDraftBinding {
                EntryEditorSheet(
                    draft: draftBinding,
                    projects: viewModel.projectOptions,
                    onSave: viewModel.saveEntryDraft
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.deleteProjectState != nil },
            set: { if !$0 { viewModel.deleteProjectState = nil } }
        )) {
            if let deletionBinding = deleteProjectBinding {
                ProjectMigrationSheet(
                    state: deletionBinding,
                    targets: viewModel.projectOptions.filter { $0.id != deletionBinding.wrappedValue.project.id },
                    onConfirm: viewModel.confirmDeleteProject
                )
            }
        }
        .alert(
            "删除词条？",
            isPresented: Binding(
                get: { viewModel.entryPendingDeletion != nil },
                set: { if !$0 { viewModel.entryPendingDeletion = nil } }
            ),
            presenting: viewModel.entryPendingDeletion
        ) { entry in
            Button("删除", role: .destructive) {
                viewModel.confirmDeleteEntry()
            }
            Button("取消", role: .cancel) {
                viewModel.entryPendingDeletion = nil
            }
        } message: { entry in
            Text("“\(entry.title)” 删除后无法恢复。")
        }
    }

    private var libraryTab: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("项目")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("新建") {
                        viewModel.startCreateProject()
                    }
                }

                List(selection: $viewModel.selectedProjectId) {
                    Label("全部项目", systemImage: "tray.full")
                        .tag(MainWindowViewModel.allProjectsSelection)

                    ForEach(Array(viewModel.projectOptions), id: \.id) { project in
                        ProjectSidebarRow(project: project, isCurrent: project.id == viewModel.currentProjectId)
                        .tag(project.id)
                    }
                }
                .listStyle(.sidebar)

                HStack {
                    Button("重命名") {
                        viewModel.startRenameSelectedProject()
                    }
                    .disabled(viewModel.selectedProject == nil)

                    Button("删除") {
                        viewModel.requestDeleteSelectedProject()
                    }
                    .disabled(viewModel.selectedProject == nil || viewModel.selectedProject?.isDefault == true)
                }

                Button("设为当前项目") {
                    viewModel.setCurrentProjectToSelected()
                }
                .disabled(viewModel.selectedProject == nil)
            }
            .padding(16)
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detailTitle)
                            .font(.title2.weight(.semibold))
                        Text("当前执行项目：\(currentProjectName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("新建词条") {
                        viewModel.startCreateEntry()
                    }
                }

                if let bannerMessage = viewModel.bannerMessage {
                    Text(bannerMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }

                TextField("按标题或内容搜索词条", text: $viewModel.entrySearchText)
                    .textFieldStyle(.roundedBorder)

                if viewModel.entries.isEmpty {
                    ContentUnavailableView(
                        "没有词条",
                        systemImage: "text.badge.plus",
                        description: Text("在当前项目下新增词条后，这里会立刻显示。")
                    )
                } else {
                    List(viewModel.entries) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(entry.title)
                                    .font(.headline)

                                if entry.isPinned {
                                    capsuleLabel("置顶")
                                }

                                capsuleLabel(entry.type)

                                if let project = viewModel.projectOptions.first(where: { $0.id == entry.projectId }) {
                                    capsuleLabel(project.name)
                                }

                                Spacer()

                                Menu("操作") {
                                    Button("编辑") {
                                        viewModel.startEditEntry(entry)
                                    }
                                    Button("删除", role: .destructive) {
                                        viewModel.requestDeleteEntry(entry)
                                    }
                                }
                            }

                            Text(previewText(for: entry.content))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)

                            HStack {
                                Text("排序 \(entry.sortOrder)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("使用 \(entry.useCount)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            viewModel.startEditEntry(entry)
                        }
                        .contextMenu {
                            Button("编辑") {
                                viewModel.startEditEntry(entry)
                            }
                            Button("删除", role: .destructive) {
                                viewModel.requestDeleteEntry(entry)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .padding(20)
        }
    }

    private var settingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox("全局快捷键") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("用于呼出或关闭快捷面板。")
                            .foregroundStyle(.secondary)
                        KeyboardShortcuts.Recorder(for: .togglePanel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("权限与启动") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("辅助功能权限")
                            Spacer()
                            permissionStateLabel(viewModel.hasAccessibilityPermission ? "已授权" : "未授权")
                        }

                        HStack(spacing: 12) {
                            Button("重新检测") {
                                viewModel.refreshPermissionState()
                            }
                            Button("请求授权") {
                                viewModel.requestAccessibilityPermission()
                            }
                            Button("打开系统设置") {
                                viewModel.openAccessibilitySettings()
                            }
                        }

                        Toggle(
                            "登录时启动",
                            isOn: Binding(
                                get: { viewModel.launchAtLoginEnabled },
                                set: { viewModel.setLaunchAtLogin($0) }
                            )
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("运行健康") {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledContent("当前版本", value: appVersionText)
                        if let snapshot = viewModel.storageHealthSnapshot {
                            LabeledContent("数据库文件", value: snapshot.databaseURL.path)
                            LabeledContent("数据库大小", value: byteCountText(snapshot.databaseSizeBytes))
                            LabeledContent("备份目录", value: snapshot.backupDirectoryURL.path)
                            LabeledContent("恢复隔离目录", value: snapshot.recoveryDirectoryURL.path)
                            LabeledContent("日志目录", value: snapshot.logsDirectoryURL.path)
                            LabeledContent("最近备份", value: latestBackupText(snapshot.latestBackupURL))
                            LabeledContent("备份数量", value: "\(snapshot.backupCount) / \(Constants.automaticBackupRetentionCount)")
                        }

                        if let summary = viewModel.executionHealthSummary {
                            HStack(spacing: 12) {
                                summaryPill("近 7 天执行", value: "\(summary.totalCount)")
                                summaryPill("成功", value: "\(summary.successCount)")
                                summaryPill("复制兜底", value: "\(summary.clipboardOnlyCount)")
                                summaryPill("失败", value: "\(summary.failedCount)")
                            }

                            HStack(spacing: 12) {
                                LabeledContent("最近执行", value: formattedDate(summary.latestExecutionAt))
                                LabeledContent("最近异常", value: formattedDate(summary.latestFailureAt))
                            }
                        }

                        HStack(spacing: 12) {
                            Button("立即备份") {
                                viewModel.createBackupNow()
                            }
                            Button("打开数据目录") {
                                viewModel.openDataDirectory()
                            }
                            Button("打开备份目录") {
                                viewModel.openBackupDirectory()
                            }
                            Button("刷新健康状态") {
                                viewModel.refreshOperationalStatus()
                            }
                        }

                        Text("自动更新当前未接入，生产发布请按本地 runbook 走“备份 -> 替换安装包 -> 回归 -> 保留最近 7 份备份”的手动流程。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("最近执行记录") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("仅展示最小排障信息，不记录词条正文。")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("刷新") {
                                viewModel.refreshLogs()
                            }
                            Button("清理 30 天前日志") {
                                viewModel.cleanupLogs()
                            }
                        }

                        if viewModel.recentExecutionLogs.isEmpty {
                            Text("当前还没有执行记录。")
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.recentExecutionLogs) { log in
                                    ExecutionLogRow(
                                        log: log,
                                        projectName: viewModel.projectName(for: log.projectId)
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
    }

    private var projectDraftBinding: Binding<MainWindowViewModel.ProjectDraft>? {
        guard viewModel.projectDraft != nil else {
            return nil
        }
        return Binding(
            get: { viewModel.projectDraft ?? MainWindowViewModel.ProjectDraft(existingProject: nil) },
            set: { viewModel.projectDraft = $0 }
        )
    }

    private var entryDraftBinding: Binding<MainWindowViewModel.EntryDraft>? {
        guard viewModel.entryDraft != nil else {
            return nil
        }
        return Binding(
            get: { viewModel.entryDraft ?? MainWindowViewModel.EntryDraft(existingEntry: nil, defaultProjectId: viewModel.currentProjectId) },
            set: { viewModel.entryDraft = $0 }
        )
    }

    private var deleteProjectBinding: Binding<MainWindowViewModel.ProjectDeletionState>? {
        guard viewModel.deleteProjectState != nil else {
            return nil
        }
        return Binding(
            get: {
                viewModel.deleteProjectState ?? MainWindowViewModel.ProjectDeletionState(
                    project: Project(name: ""),
                    entryCount: 0,
                    targetProjectId: ""
                )
            },
            set: { viewModel.deleteProjectState = $0 }
        )
    }

    private var detailTitle: String {
        if viewModel.selectedProjectId == MainWindowViewModel.allProjectsSelection {
            return "全部词条"
        }
        return viewModel.selectedProject?.name ?? "词条"
    }

    private var currentProjectName: String {
        viewModel.projectOptions.first(where: { $0.id == viewModel.currentProjectId })?.name ?? "未设置"
    }

    private func capsuleLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .foregroundStyle(.secondary)
    }

    private func permissionStateLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    private func previewText(for content: String) -> String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        return "\(shortVersion) (\(buildVersion))"
    }

    private func latestBackupText(_ url: URL?) -> String {
        guard let url else {
            return "暂无"
        }
        let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let timestamp = modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "未知时间"
        return "\(url.lastPathComponent) · \(timestamp)"
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "暂无"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func byteCountText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func summaryPill(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }
}

private struct ProjectSidebarRow: View {
    let project: Project
    let isCurrent: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .fontWeight(isCurrent ? .semibold : .regular)
                if project.isDefault {
                    Text("通用项目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isCurrent {
                Image(systemName: "scope")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

private struct ExecutionLogRow: View {
    let log: ExecutionLog
    let projectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(resultTitle)
                    .font(.subheadline.weight(.semibold))
                Text(projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(log.createdAt.formatted(date: .abbreviated, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                infoPill("目标应用", value: log.frontAppBundleId ?? "未知")
                if let observedAppTitle {
                    infoPill("粘贴前前台", value: observedAppTitle)
                }
                infoPill("权限", value: log.hasAccessibility ? "已授权" : "未授权")
                infoPill("复制", value: log.clipboardSuccess ? "成功" : "失败")
                infoPill("自动粘贴", value: log.pasteAttempted ? (log.pasteSuccess ? "成功" : "失败") : "未尝试")
                if let durationText {
                    infoPill("耗时", value: durationText)
                }
            }

            if let failureReasonTitle {
                infoPill("失败原因", value: failureReasonTitle)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var resultTitle: String {
        switch log.result {
        case Constants.ExecutionResult.success.rawValue:
            return "执行成功"
        case Constants.ExecutionResult.clipboardOnly.rawValue:
            return "复制兜底"
        default:
            return "执行失败"
        }
    }

    private var observedAppTitle: String? {
        guard let observedAppBundleId = log.observedAppBundleId else {
            return nil
        }
        guard observedAppBundleId != log.frontAppBundleId else {
            return nil
        }
        return observedAppBundleId
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
        case Constants.ExecutionFailureReason.clipboardWriteFailed.rawValue:
            return "剪贴板写入失败"
        case Constants.ExecutionFailureReason.accessibilityNotGranted.rawValue:
            return "辅助功能权限未授权"
        case Constants.ExecutionFailureReason.targetAppNotRestored.rawValue:
            return "原目标应用未恢复前台"
        case Constants.ExecutionFailureReason.pasteEventCreationFailed.rawValue:
            return "自动粘贴事件创建失败"
        default:
            return "未分类"
        }
    }

    private func infoPill(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }
}

private struct ProjectEditorSheet: View {
    @Binding var draft: MainWindowViewModel.ProjectDraft
    let onSave: () -> Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.existingProject == nil ? "新建项目" : "重命名项目")
                .font(.title3.weight(.semibold))

            TextField("项目名称", text: $draft.name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    if onSave() {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

private struct EntryEditorSheet: View {
    @Binding var draft: MainWindowViewModel.EntryDraft
    let projects: [Project]
    let onSave: () -> Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.existingEntry == nil ? "新建词条" : "编辑词条")
                .font(.title3.weight(.semibold))

            TextField("标题", text: $draft.title)
                .textFieldStyle(.roundedBorder)

            Picker("所属项目", selection: $draft.projectId) {
                ForEach(projects) { project in
                    Text(project.name).tag(project.id)
                }
            }

            Picker("类型", selection: $draft.type) {
                ForEach(Constants.EntryType.allCases, id: \.rawValue) { type in
                    Text(type.rawValue).tag(type.rawValue)
                }
            }

            Toggle("置顶", isOn: $draft.isPinned)

            Stepper(value: $draft.sortOrder, in: -999...999) {
                Text("排序值：\(draft.sortOrder)")
            }

            Text("内容")
                .font(.headline)

            TextEditor(text: $draft.content)
                .font(.body)
                .frame(minHeight: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    if onSave() {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 560)
    }
}

private struct ProjectMigrationSheet: View {
    @Binding var state: MainWindowViewModel.ProjectDeletionState
    let targets: [Project]
    let onConfirm: () -> Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("删除前先迁移词条")
                .font(.title3.weight(.semibold))

            Text("项目 “\(state.project.name)” 下还有 \(state.entryCount) 条词条，必须先迁移到其他项目。")
                .foregroundStyle(.secondary)

            Picker("迁移到", selection: $state.targetProjectId) {
                ForEach(targets) { project in
                    Text(project.name).tag(project.id)
                }
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("迁移并删除") {
                    if onConfirm() {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
