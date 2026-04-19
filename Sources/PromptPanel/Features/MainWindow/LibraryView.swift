import SwiftUI

struct LibraryView: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        HStack(spacing: 0) {
            projectsColumn
                .frame(width: 200)
                .background(Constants.VisualStyle.sidebar)

            verticalDivider

            entriesColumn
                .frame(width: 360)
                .background(Constants.VisualStyle.surface)

            verticalDivider

            PreviewPane(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Constants.VisualStyle.surface)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Constants.VisualStyle.divider)
            .frame(width: 0.5)
    }

    // MARK: Projects column

    private var projectsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                SectionHeading(text: "项目")
                Spacer(minLength: 0)
                Button {
                    viewModel.startCreateProject()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("新建项目")
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ProjectRow(
                        title: "全部项目",
                        systemImage: "tray.full",
                        count: viewModel.entries.count,
                        isActive: viewModel.selectedProjectId == MainWindowViewModel.allProjectsSelection,
                        isCurrent: false
                    ) {
                        viewModel.selectedProjectId = MainWindowViewModel.allProjectsSelection
                    }
                    .contextMenu {
                        Button("新建项目") { viewModel.startCreateProject() }
                    }

                    ForEach(viewModel.projectOptions) { project in
                        ProjectRow(
                            title: project.name,
                            systemImage: nil,
                            count: nil,
                            isActive: viewModel.selectedProjectId == project.id,
                            isCurrent: project.id == viewModel.currentProjectId
                        ) {
                            viewModel.selectedProjectId = project.id
                        }
                        .contextMenu {
                            Button("设为当前执行项目") {
                                viewModel.selectedProjectId = project.id
                                viewModel.setCurrentProjectToSelected()
                            }
                            .disabled(project.id == viewModel.currentProjectId)
                            Button("重命名") {
                                viewModel.selectedProjectId = project.id
                                viewModel.startRenameSelectedProject()
                            }
                            Divider()
                            Button("删除", role: .destructive) {
                                viewModel.selectedProjectId = project.id
                                viewModel.requestDeleteSelectedProject()
                            }
                            .disabled(project.isDefault)
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .scrollIndicators(.hidden)

            Divider()
                .opacity(0.25)

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    viewModel.setCurrentProjectToSelected()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                            .font(.system(size: 10.5, weight: .medium))
                        Text("设为当前执行项目")
                            .font(.system(size: 11.5, weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(canMarkAsCurrent ? Constants.VisualStyle.textSecondary : Constants.VisualStyle.textQuaternary)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canMarkAsCurrent)

                HStack(spacing: 6) {
                    Button {
                        viewModel.startRenameSelectedProject()
                    } label: {
                        actionLabel(title: "重命名", systemImage: "pencil", enabled: viewModel.selectedProject != nil)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedProject == nil)

                    Button(role: .destructive) {
                        viewModel.requestDeleteSelectedProject()
                    } label: {
                        actionLabel(
                            title: "删除",
                            systemImage: "trash",
                            enabled: viewModel.selectedProject != nil && viewModel.selectedProject?.isDefault == false,
                            tone: .danger
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedProject == nil || viewModel.selectedProject?.isDefault == true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    private var canMarkAsCurrent: Bool {
        guard let selected = viewModel.selectedProject else {
            return false
        }
        return selected.id != viewModel.currentProjectId
            && viewModel.selectedProjectId != MainWindowViewModel.allProjectsSelection
    }

    private enum FooterTone {
        case neutral
        case danger
    }

    private func actionLabel(title: String, systemImage: String, enabled: Bool, tone: FooterTone = .neutral) -> some View {
        let foreground: Color = {
            if !enabled {
                return Constants.VisualStyle.textQuaternary
            }
            switch tone {
            case .neutral: return Constants.VisualStyle.textSecondary
            case .danger: return Constants.VisualStyle.danger
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .medium))
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: Entries column

    private var entriesColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()
                .background(Constants.VisualStyle.divider)

            if hasFilterChips {
                filterChipsRow
                Divider()
                    .background(Constants.VisualStyle.divider)
            }

            countSortRow
            Divider()
                .background(Constants.VisualStyle.divider)

            entriesList
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Constants.VisualStyle.textTertiary)
            TextField("搜索标题或内容", text: $viewModel.entrySearchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Constants.VisualStyle.text)
            if viewModel.entrySearchText.isEmpty {
                KbdLabel(text: "⌘F")
            } else {
                Button {
                    viewModel.entrySearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Constants.VisualStyle.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Constants.VisualStyle.border, lineWidth: 0.5)
        )
    }

    private var hasFilterChips: Bool {
        viewModel.availableEntryKinds.isEmpty == false || viewModel.topTags().isEmpty == false
    }

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                FilterChip(
                    label: "全部",
                    count: viewModel.entries.count,
                    isActive: viewModel.entryKindFilter == nil && viewModel.entryTagFilter == nil
                ) {
                    viewModel.clearEntryFilters()
                }
                if viewModel.availableEntryKinds.isEmpty == false {
                    chipDivider
                    ForEach(viewModel.availableEntryKinds, id: \.rawValue) { kind in
                        FilterChip(
                            label: kind.displayName,
                            systemImage: kind.symbolName,
                            count: kindCount(for: kind),
                            isActive: viewModel.entryKindFilter == kind.rawValue
                        ) {
                            viewModel.toggleEntryKindFilter(kind)
                        }
                    }
                }
                if viewModel.topTags().isEmpty == false {
                    chipDivider
                    ForEach(viewModel.topTags(limit: 8), id: \.0) { tag, count in
                        FilterChip(
                            label: "#\(tag)",
                            count: count,
                            isActive: viewModel.entryTagFilter == tag
                        ) {
                            viewModel.toggleEntryTagFilter(tag)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var chipDivider: some View {
        Rectangle()
            .fill(Constants.VisualStyle.divider)
            .frame(width: 1, height: 14)
            .padding(.horizontal, 4)
    }

    private func kindCount(for kind: Constants.EntryType) -> Int {
        viewModel.entries.filter { $0.type == kind.rawValue }.count
    }

    private var countSortRow: some View {
        HStack(spacing: 0) {
            Text("\(viewModel.displayedEntries.count) 条")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Constants.VisualStyle.textQuaternary)

            Spacer(minLength: 0)

            Menu {
                ForEach(MainWindowViewModel.EntrySortMode.allCases) { mode in
                    Button(mode.title) {
                        viewModel.entrySortMode = mode
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.entrySortMode.title)
                        .font(.system(size: 11))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Button {
                viewModel.startCreateEntry()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                    Text("新建")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Constants.VisualStyle.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var entriesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.displayedEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.displayedEntries) { entry in
                            EntryListRow(
                                entry: entry,
                                isSelected: entry.id == (viewModel.selectedEntry?.id ?? ""),
                                projectName: projectName(for: entry)
                            ) {
                                viewModel.selectedEntryId = entry.id
                            }
                            .id(entry.id)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.selectedEntry?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
            Text(emptyStateTitle)
                .font(.system(size: 12))
                .foregroundStyle(Constants.VisualStyle.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 32)
    }

    private var emptyStateTitle: String {
        if viewModel.entrySearchText.isEmpty {
            return "当前还没有词条\n点击右上 + 开始添加"
        }
        return "没有匹配的词条\n换个关键词试试"
    }

    private func projectName(for entry: Entry) -> String? {
        viewModel.projectOptions.first(where: { $0.id == entry.projectId })?.name
    }
}

private struct ProjectRow: View {
    let title: String
    let systemImage: String?
    let count: Int?
    let isActive: Bool
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage ?? (isCurrent ? "folder.fill" : "folder"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isActive ? Constants.VisualStyle.textSecondary : Constants.VisualStyle.textTertiary)
                    .frame(width: 13)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isActive ? Constants.VisualStyle.text : Constants.VisualStyle.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if isCurrent {
                    Text("当前")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Constants.VisualStyle.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Constants.VisualStyle.accentDim)
                        )
                }
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Constants.VisualStyle.textQuaternary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EntryListRow: View {
    let entry: Entry
    let isSelected: Bool
    let projectName: String?
    let onTap: () -> Void

    var body: some View {
        let type = Constants.EntryType.resolve(entry.type)
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: type.symbolName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Constants.VisualStyle.text : Constants.VisualStyle.textSecondary)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Constants.VisualStyle.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Constants.VisualStyle.warn)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(previewText(for: entry.content))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 6) {
                        Text("\(entry.useCount) 次")
                            .font(.system(size: 10.5, design: .monospaced))
                        Text("·")
                            .opacity(0.5)
                        Text(lastUsedText)
                            .font(.system(size: 10.5))
                        if let projectName {
                            Text("·")
                                .opacity(0.5)
                            Text(projectName)
                                .font(.system(size: 10.5))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        if entry.tags.isEmpty == false {
                            TagChipsInline(tags: entry.tags, max: 2)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Constants.VisualStyle.textQuaternary)
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? Constants.VisualStyle.accent : Color.clear)
                    .frame(width: 2)
            }
            .background(isSelected ? Color.white.opacity(0.04) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var lastUsedText: String {
        guard let lastUsedAt = entry.lastUsedAt else {
            return "未使用"
        }
        return RelativeDateTimeFormatter().localizedString(for: lastUsedAt, relativeTo: Date())
    }

    private func previewText(for content: String) -> String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}

private struct PreviewPane: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        if let entry = viewModel.selectedEntry {
            content(for: entry)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
            Text("选择一条词条查看")
                .font(.system(size: 13))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(for entry: Entry) -> some View {
        let type = Constants.EntryType.resolve(entry.type)
        return VStack(alignment: .leading, spacing: 0) {
            header(for: entry, type: type)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .background(
                    VStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .fill(Constants.VisualStyle.divider)
                            .frame(height: 0.5)
                    }
                )

            ScrollView {
                Text(entry.content)
                    .font(.system(size: 13))
                    .foregroundStyle(Constants.VisualStyle.text)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)

            footer(for: entry)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Rectangle()
                        .fill(Constants.VisualStyle.divider)
                        .frame(height: 0.5),
                    alignment: .top
                )
        }
    }

    private func header(for entry: Entry, type: Constants.EntryType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: type.symbolName)
                        .font(.system(size: 10, weight: .medium))
                    Text(type.displayName)
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(Constants.VisualStyle.textTertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

                if entry.isPinned {
                    HStack(spacing: 3) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                        Text("已置顶")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(Constants.VisualStyle.warn)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Constants.VisualStyle.warnDim)
                    )
                }

                Text("· \(entry.useCount) 次使用 · \(lastUsedText(entry))")
                    .font(.system(size: 11))
                    .foregroundStyle(Constants.VisualStyle.textQuaternary)

                Spacer(minLength: 0)

                Menu {
                    Button("复制内容") { viewModel.copyEntryContent(entry) }
                    Button("编辑词条") { viewModel.startEditEntry(entry) }
                    Button(entry.isPinned ? "取消置顶" : "置顶") { viewModel.togglePin(entry) }
                    Divider()
                    Button("删除", role: .destructive) { viewModel.requestDeleteEntry(entry) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                        .frame(width: 26, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            Text(entry.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Constants.VisualStyle.text)
                .lineLimit(2)
                .truncationMode(.tail)

            HStack(spacing: 6) {
                PrimaryActionButton(title: "复制", systemImage: "doc.on.doc", shortcut: "⌘C") {
                    viewModel.copyEntryContent(entry)
                }
                GhostActionButton(title: "编辑", systemImage: "pencil", shortcut: "⌘E") {
                    viewModel.startEditEntry(entry)
                }
                Spacer(minLength: 0)
                QuietIconButton(
                    systemImage: entry.isPinned ? "pin.slash" : "pin",
                    tint: entry.isPinned ? Constants.VisualStyle.warn : nil,
                    help: entry.isPinned ? "取消置顶" : "置顶"
                ) {
                    viewModel.togglePin(entry)
                }
                QuietIconButton(systemImage: "trash", help: "删除") {
                    viewModel.requestDeleteEntry(entry)
                }
            }
        }
    }

    private func footer(for entry: Entry) -> some View {
        HStack(spacing: 20) {
            MetaInline(label: "项目", value: projectName(for: entry) ?? "未归属")
            Rectangle()
                .fill(Constants.VisualStyle.divider)
                .frame(width: 1, height: 16)
            HStack(spacing: 8) {
                Text("标签")
                    .font(.system(size: 11))
                    .foregroundStyle(Constants.VisualStyle.textQuaternary)
                if entry.tags.isEmpty {
                    Text("无")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Constants.VisualStyle.textQuaternary)
                } else {
                    HStack(spacing: 4) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Constants.VisualStyle.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                        }
                    }
                }
            }
            Rectangle()
                .fill(Constants.VisualStyle.divider)
                .frame(width: 1, height: 16)
            MetaInline(label: "更新时间", value: formattedUpdatedAt(entry))
            Spacer(minLength: 0)
        }
    }

    private func projectName(for entry: Entry) -> String? {
        viewModel.projectOptions.first(where: { $0.id == entry.projectId })?.name
    }

    private func lastUsedText(_ entry: Entry) -> String {
        guard let lastUsedAt = entry.lastUsedAt else {
            return "未使用"
        }
        return RelativeDateTimeFormatter().localizedString(for: lastUsedAt, relativeTo: Date())
    }

    private func formattedUpdatedAt(_ entry: Entry) -> String {
        entry.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

struct TagChipsInline: View {
    let tags: [String]
    let max: Int

    init(tags: [String], max: Int = 2) {
        self.tags = tags
        self.max = max
    }

    var body: some View {
        let shown = Array(tags.prefix(max))
        let rest = tags.count - shown.count
        HStack(spacing: 4) {
            ForEach(shown, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Constants.VisualStyle.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            }
            if rest > 0 {
                Text("+\(rest)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Constants.VisualStyle.textQuaternary)
            }
        }
    }
}

private struct MetaInline: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
            Text(value)
                .font(.system(size: 11.5))
                .foregroundStyle(Constants.VisualStyle.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
