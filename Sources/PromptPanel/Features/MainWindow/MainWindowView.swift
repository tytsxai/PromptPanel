import AppKit
import Foundation
import KeyboardShortcuts
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel
    @State private var showsStorageDetails: Bool = false
    @State private var showsRecentLogs: Bool = false

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            .ignoresSafeArea()

            TabView(selection: $viewModel.selectedTab) {
                libraryTab
                    .tag(MainWindowViewModel.Tab.library)
                    .tabItem {
                        Label("内容库", systemImage: "books.vertical")
                    }

                settingsTab
                    .tag(MainWindowViewModel.Tab.settings)
                    .tabItem {
                        Label("设置", systemImage: "gearshape")
                    }
            }
            .padding(Constants.Interface.outerPadding)
        }
        .frame(
            minWidth: Constants.MainWindowLayout.minContentSize.width,
            minHeight: Constants.MainWindowLayout.minContentSize.height
        )
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("项目")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Button("新建") {
                        viewModel.startCreateProject()
                    }
                }

                ScrollView {
                    LazyVStack(spacing: Constants.Interface.rowSpacing) {
                        sidebarProjectButton(
                            title: "全部项目",
                            subtitle: nil,
                            systemImage: "tray.full",
                            isSelected: viewModel.selectedProjectId == MainWindowViewModel.allProjectsSelection,
                            isCurrent: false
                        ) {
                            viewModel.selectedProjectId = MainWindowViewModel.allProjectsSelection
                        }

                        ForEach(Array(viewModel.projectOptions), id: \.id) { project in
                            sidebarProjectButton(
                                title: project.name,
                                subtitle: project.isDefault ? "通用项目" : nil,
                                systemImage: nil,
                                isSelected: viewModel.selectedProjectId == project.id,
                                isCurrent: project.id == viewModel.currentProjectId
                            ) {
                                viewModel.selectedProjectId = project.id
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
                .frame(height: sidebarListHeight, alignment: .top)

                HStack(spacing: 6) {
                    Button("重命名") {
                        viewModel.startRenameSelectedProject()
                    }
                    .disabled(viewModel.selectedProject == nil)

                    Button("删除") {
                        viewModel.requestDeleteSelectedProject()
                    }
                    .disabled(viewModel.selectedProject == nil || viewModel.selectedProject?.isDefault == true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("设为当前项目") {
                    viewModel.setCurrentProjectToSelected()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.selectedProject == nil)

                Spacer(minLength: 0)
            }
            .padding(Constants.Interface.outerPadding)
            .background(glassCard)
            .navigationSplitViewColumnWidth(min: 188, ideal: 204, max: 220)
        } detail: {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(detailTitle)
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text("\(viewModel.entries.count) 条词条 · 当前执行项目：\(currentProjectName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        Spacer()

                        Button("新建词条") {
                            viewModel.startCreateEntry()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if let bannerMessage = viewModel.bannerMessage {
                        detailBanner(message: bannerMessage)
                    }

                    searchFieldCard

                    if viewModel.entries.isEmpty {
                        ContentUnavailableView(
                            "没有词条",
                            systemImage: "text.badge.plus",
                            description: Text("在当前项目下新增词条后，这里会立刻显示。")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(detailListSurface)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Constants.Interface.rowSpacing) {
                                ForEach(viewModel.entries) { entry in
                                    entryCard(entry)
                                }
                            }
                            .padding(6)
                        }
                        .background(detailListSurface)
                        .clipShape(RoundedRectangle(cornerRadius: Constants.Interface.cardCornerRadius, style: .continuous))
                    }
                }
                .frame(maxWidth: 940, alignment: .leading)
                .padding(Constants.Interface.outerPadding)
                .background(glassCard)

                Spacer(minLength: 0)
            }
        }
        .background(.clear)
    }

    private var settingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.Interface.sectionSpacing) {
                if let bannerMessage = viewModel.bannerMessage {
                    detailBanner(message: bannerMessage)
                }

                HStack(alignment: .top, spacing: Constants.Interface.sectionSpacing) {
                    VStack(spacing: Constants.Interface.sectionSpacing) {
                        settingsCard(
                            title: "快捷面板",
                            description: "只放会直接影响主链路的开关。"
                        ) {
                            Toggle(
                                "固定快捷面板",
                                isOn: Binding(
                                    get: { viewModel.isPanelPinned },
                                    set: { viewModel.setPanelPinned($0) }
                                )
                            )

                            Text(viewModel.isPanelPinned ? "开启后，快捷面板会持续置顶；适合需要边看边选的场景。" : "关闭后，快捷面板失去焦点会自动收起，执行后更利落。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        settingsCard(
                            title: "快捷键",
                            description: "这里只保留呼出面板所需的唯一入口。"
                        ) {
                            settingsValueRow("当前组合键", value: viewModel.hotkeySummary())

                            KeyboardShortcuts.Recorder(for: .togglePanel)
                                .labelsHidden()
                        }

                        settingsCard(
                            title: "权限与启动",
                            description: "权限和开机项都在这里收口，不把低频配置扩散到面板里。"
                        ) {
                            HStack(spacing: 12) {
                                Text("辅助功能权限")
                                Spacer()
                                permissionStateLabel(viewModel.hasAccessibilityPermission ? "已授权" : "未授权")
                            }

                            HStack(spacing: 8) {
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
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Toggle(
                                "登录时启动",
                                isOn: Binding(
                                    get: { viewModel.launchAtLoginEnabled },
                                    set: { viewModel.setLaunchAtLogin($0) }
                                )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    VStack(spacing: Constants.Interface.sectionSpacing) {
                        settingsCard(
                            title: "运行概况",
                            description: "默认先给出健康判断，不把整页变成诊断面板。"
                        ) {
                            settingsValueRow("当前版本", value: appVersionText)
                            settingsValueRow("更新状态", value: viewModel.updaterStatusMessage, lineLimit: 3)

                            if let snapshot = viewModel.storageHealthSnapshot {
                                settingsValueRow("数据库大小", value: byteCountText(snapshot.databaseSizeBytes))
                                settingsValueRow("备份数量", value: "\(snapshot.backupCount) / \(Constants.automaticBackupRetentionCount)")
                                settingsValueRow("最近备份", value: latestBackupSummary(snapshot.latestBackupURL))
                            }

                            if let summary = viewModel.executionHealthSummary {
                                HStack(spacing: 10) {
                                    summaryPill("近 7 天执行", value: "\(summary.totalCount)")
                                    summaryPill("成功", value: "\(summary.successCount)")
                                    summaryPill("复制兜底", value: "\(summary.clipboardOnlyCount)")
                                    summaryPill("失败", value: "\(summary.failedCount)")
                                }

                                settingsValueRow("最近执行", value: formattedDate(summary.latestExecutionAt))
                                settingsValueRow("最近异常", value: formattedDate(summary.latestFailureAt))
                            } else {
                                Text("最近 7 天还没有执行记录。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            DisclosureGroup(
                                "查看路径与备份详情",
                                isExpanded: $showsStorageDetails
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    if let snapshot = viewModel.storageHealthSnapshot {
                                        settingsValueRow("最近备份文件", value: latestBackupFileName(snapshot.latestBackupURL), lineLimit: 2)
                                        settingsPathRow("数据库文件", value: snapshot.databaseURL.path)
                                        settingsPathRow("备份目录", value: snapshot.backupDirectoryURL.path)
                                        settingsPathRow("恢复隔离目录", value: snapshot.recoveryDirectoryURL.path)
                                        settingsPathRow("日志目录", value: snapshot.logsDirectoryURL.path)
                                    } else {
                                        Text("尚未加载健康信息。")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .disclosureGroupStyle(.automatic)
                        }

                        settingsCard(
                            title: "维护操作",
                            description: "所有低频维护动作统一收在这里，不让设置页继续扩散。"
                        ) {
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 108, maximum: 150), spacing: 8, alignment: .leading)
                                ],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                Button("刷新状态") {
                                    viewModel.refreshOperationalStatus()
                                    viewModel.refreshUpdaterStatus()
                                }

                                Button("检查更新") {
                                    viewModel.checkForUpdates()
                                }
                                .disabled(viewModel.canCheckForUpdates == false)

                                Button("立即备份") {
                                    viewModel.createBackupNow()
                                }

                                Button("打开数据目录") {
                                    viewModel.openDataDirectory()
                                }

                                Button("打开备份目录") {
                                    viewModel.openBackupDirectory()
                                }

                                Button("清理旧日志") {
                                    viewModel.cleanupLogs()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Text("Sparkle 只在 feed 和公钥都配置完成后启用；其余情况下沿用本地打包与备份恢复链路。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DisclosureGroup(
                                "查看最近执行记录",
                                isExpanded: $showsRecentLogs
                            ) {
                                VStack(alignment: .leading, spacing: 10) {
                                    if viewModel.recentExecutionLogs.isEmpty {
                                        Text("当前还没有执行记录。")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(viewModel.recentExecutionLogs) { log in
                                            ExecutionLogRow(
                                                log: log,
                                                projectName: viewModel.projectName(for: log.projectId)
                                            )
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .disclosureGroupStyle(.automatic)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(Constants.Interface.outerPadding)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollContentBackground(.hidden)
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

    private var sidebarListHeight: CGFloat {
        let rowCount = max(viewModel.projectOptions.count + 1, 1)
        return min(
            CGFloat(rowCount) * Constants.MainWindowLayout.sidebarRowHeight,
            Constants.MainWindowLayout.sidebarListMaxHeight
        )
    }

    private func sidebarProjectButton(
        title: String,
        subtitle: String?,
        systemImage: String?,
        isSelected: Bool,
        isCurrent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.88) : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if isCurrent {
                    Image(systemName: "scope")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor.opacity(0.65))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.11) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous))
    }

    private func capsuleLabel(_ text: String) -> some View {
        Text(badgeDisplayText(text))
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.08)))
            .foregroundStyle(.secondary)
    }

    private func badgeDisplayText(_ text: String) -> String {
        let limit = 14
        guard text.count > limit else {
            return text
        }
        return "\(text.prefix(limit - 3))..."
    }

    private func detailBanner(message: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var searchFieldCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("按标题或内容搜索词条", text: $viewModel.entrySearchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    private func entryCard(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)

                        if entry.isPinned {
                            capsuleLabel("置顶")
                        }

                        if let projectName = projectName(for: entry) {
                            capsuleLabel(projectName)
                        }
                    }

                    Text(previewText(for: entry.content))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                Menu {
                    Button("编辑") {
                        viewModel.startEditEntry(entry)
                    }
                    Button("删除", role: .destructive) {
                        viewModel.requestDeleteEntry(entry)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 18, height: 18)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            HStack(spacing: 6) {
                cardMetaPill(title: "排序", value: "\(entry.sortOrder)")
                cardMetaPill(title: "使用", value: "\(entry.useCount)")

                if let lastUsedAt = entry.lastUsedAt {
                    cardMetaPill(title: "最近使用", value: relativeDateText(for: lastUsedAt))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.046))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous))
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

    private func projectName(for entry: Entry) -> String? {
        viewModel.projectOptions.first(where: { $0.id == entry.projectId })?.name
    }

    private func cardMetaPill(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Capsule().fill(Color.secondary.opacity(0.055)))
    }

    private func relativeDateText(for date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private var detailListSurface: some View {
        RoundedRectangle(cornerRadius: Constants.Interface.cardCornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.024))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Interface.cardCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
    }

    private func permissionStateLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    private func previewText(for content: String) -> String {
        content
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\t", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        return "\(shortVersion) (\(buildVersion))"
    }

    private func latestBackupSummary(_ url: URL?) -> String {
        guard let url else {
            return "暂无"
        }
        let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "未知时间"
    }

    private func latestBackupFileName(_ url: URL?) -> String {
        guard let url else {
            return "暂无"
        }
        return url.lastPathComponent
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
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func settingsCard<Content: View>(
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(Constants.Interface.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.Interface.cardCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Interface.cardCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        )
    }

    private func settingsValueRow(_ label: String, value: String, lineLimit: Int = 1) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.trailing)
                .lineLimit(lineLimit)
                .truncationMode(.middle)
        }
    }

    private func settingsPathRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: Constants.Interface.cardCornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.026))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Interface.cardCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.035), lineWidth: 1)
            )
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
                if let triggerSourceTitle {
                    infoPill("触发方式", value: triggerSourceTitle)
                }
                infoPill("权限", value: log.hasAccessibility ? "已授权" : "未授权")
                infoPill("复制", value: log.clipboardSuccess ? "成功" : "失败")
                infoPill("自动粘贴", value: log.pasteAttempted ? (log.pasteSuccess ? "成功" : "失败") : "未尝试")
                if let restoreWaitText {
                    infoPill("回前台耗时", value: restoreWaitText)
                }
                if let durationText {
                    infoPill("耗时", value: durationText)
                }
            }

            if let failureReasonTitle {
                infoPill("失败原因", value: failureReasonTitle)
            }
        }
        .padding(Constants.Interface.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.Interface.cardCornerRadius, style: .continuous)
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

    private var restoreWaitText: String? {
        guard let durationMs = log.targetAppRestoreDurationMs else {
            return nil
        }
        return "\(durationMs) ms"
    }

    private var triggerSourceTitle: String? {
        guard let triggerSource = log.triggerSource else {
            return nil
        }

        switch triggerSource {
        case Constants.ExecutionTrigger.keyboardSubmit.rawValue:
            return "回车"
        case Constants.ExecutionTrigger.pointerClick.rawValue:
            return "点击"
        default:
            return triggerSource
        }
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

            DisclosureGroup("高级设置") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("类型", selection: $draft.type) {
                        ForEach(Constants.EntryType.allCases, id: \.rawValue) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }

                    Toggle("置顶", isOn: $draft.isPinned)

                    Stepper(value: $draft.sortOrder, in: -999...999) {
                        Text("排序值：\(draft.sortOrder)")
                    }
                }
                .padding(.top, 8)
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
