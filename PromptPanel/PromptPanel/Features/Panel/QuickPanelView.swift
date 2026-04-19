import AppKit
import KeyboardShortcuts
import SwiftUI

struct QuickPanelView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: QuickPanelViewModel

    var body: some View {
        VStack(spacing: 16) {
            header

            if let statusMessage = viewModel.statusMessage {
                statusBanner(statusMessage)
            }

            resultsSection
        }
        .padding(20)
        .frame(width: Constants.panelContentSize.width, height: Constants.panelContentSize.height)
        .background(panelSurface)
        .shadow(color: .black.opacity(0.28), radius: 30, x: 0, y: 18)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("快捷执行")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text(trimmedQuery.isEmpty ? currentProjectName : "在 \(currentProjectName) 中搜索")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button {
                        viewModel.setPanelPinned(!appState.isPanelPinned)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: appState.isPanelPinned ? "pin.fill" : "pin")
                            Text(appState.isPanelPinned ? "已固定" : "固定")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(appState.isPanelPinned ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(appState.isPanelPinned ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .help(appState.isPanelPinned ? "当前面板会持续置顶显示" : "点击后让面板持续置顶显示")

                    metaPill(systemImage: "keyboard", text: hotkeyHintText)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("项目范围")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    Picker("当前项目", selection: Binding(
                        get: { viewModel.currentProjectId },
                        set: { viewModel.activateProject($0) }
                    )) {
                        ForEach(viewModel.projects) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(sectionSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    summaryPill(systemImage: "text.magnifyingglass", text: resultSummaryText)
                    summaryPill(systemImage: "cursorarrow.rays", text: "双击 / 回车执行")
                }
            }

            KeyAwareSearchField(
                text: Binding(
                    get: { viewModel.query },
                    set: { viewModel.query = $0 }
                ),
                placeholder: "搜索标题或内容",
                focusToken: viewModel.focusToken,
                onMoveSelection: viewModel.moveSelection,
                onSubmit: { viewModel.executeSelection(triggerSource: .keyboardSubmit) },
                onEscape: viewModel.closePanel,
                onFocusResolved: viewModel.handleSearchFieldFocus
            )
            .frame(height: 46)

            HStack(spacing: 10) {
                Text(selectionHintText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text("↑↓ 选择  双击 / Return 执行  Esc 关闭")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var resultsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(trimmedQuery.isEmpty ? "候选词条" : "搜索结果")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if viewModel.isLoadingEntries {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("\(viewModel.entries.count) 条")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.025))

            Divider()
                .overlay(Color.white.opacity(0.06))

            results
                .padding(12)
        }
        .background(resultsSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.entries.isEmpty, viewModel.isLoadingEntries {
                        loadingState
                    } else if viewModel.entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                            entryRow(entry, index: index)
                                .id(entry.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.isLoadingEntries, viewModel.entries.isEmpty == false {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 4)
                }
            }
            .onChange(of: viewModel.selectedIndex) { _, _ in
                guard let selectedEntry = viewModel.selectedEntry else {
                    return
                }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(selectedEntry.id, anchor: .center)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)

            Text("正在刷新词条")
                .font(.headline)

            Text("会保留当前项目范围，马上显示最新结果。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 72)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 70, height: 70)

                Image(systemName: trimmedQuery.isEmpty ? "tray.full" : "sparkle.magnifyingglass")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title3.weight(.semibold))

                Text(emptyStateDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            HStack(spacing: 10) {
                emptyStateTip(
                    systemImage: trimmedQuery.isEmpty ? "plus.circle" : "character.cursor.ibeam",
                    title: trimmedQuery.isEmpty ? "去主界面补词条" : "换个关键词",
                    detail: trimmedQuery.isEmpty ? "新增后这里会立即可搜可用。" : "标题和正文都会参与命中。"
                )
                emptyStateTip(
                    systemImage: "rectangle.and.text.magnifyingglass",
                    title: "支持标题和正文搜索",
                    detail: "不用记完整名称，输片段也能筛出结果。"
                )
            }
            .frame(maxWidth: 430)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 56)
    }

    private func entryRow(_ entry: Entry, index: Int) -> some View {
        let isSelected = index == viewModel.selectedIndex

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if entry.isPinned {
                    labelBadge("置顶", tone: .accent)
                }

                if shouldShowDefaultBadge(for: entry) {
                    labelBadge("通用项目", tone: .secondary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    labelBadge("已选中", tone: .accent)
                    labelBadge("双击执行", tone: .secondary)
                }
            }

            Text(previewText(for: entry.content))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            HStack(spacing: 8) {
                metaBadge(relativeLastUsedText(for: entry))
                metaBadge("使用 \(entry.useCount)")

                Spacer(minLength: 0)

                if entry.projectId == viewModel.currentProjectId {
                    Text(currentProjectName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground(isSelected: isSelected))
        .overlay(rowBorder(isSelected: isSelected))
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.88))
                    .frame(width: 4, height: 44)
                    .padding(.leading, 6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(count: 2) {
            viewModel.selectEntry(at: index)
            viewModel.executeSelection(force: true, triggerSource: .pointerClick)
        }
        .onTapGesture {
            viewModel.selectEntry(at: index)
        }
    }

    private func shouldShowDefaultBadge(for entry: Entry) -> Bool {
        entry.projectId == appState.defaultProjectId && entry.projectId != viewModel.currentProjectId
    }

    private func labelBadge(_ text: String, tone: BadgeTone) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tone == .accent ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.14))
            )
            .foregroundStyle(tone == .accent ? Color.accentColor : .secondary)
    }

    private func metaPill(systemImage: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }

    private func summaryPill(systemImage: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
    }

    private func metaBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.04))
            )
    }

    private func statusBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusAccentColor.opacity(0.18))
                    .frame(width: 28, height: 28)

                Image(systemName: statusIconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusAccentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitleText)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if viewModel.statusTone == .warning {
                Button("打开系统设置") {
                    viewModel.openAccessibilitySettings()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusAccentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(statusAccentColor.opacity(0.10))
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            statusBackgroundColor,
                            statusBackgroundColor.opacity(0.82)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(statusAccentColor.opacity(0.24), lineWidth: 1)
        )
    }

    private func previewText(for content: String) -> String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func relativeLastUsedText(for entry: Entry) -> String {
        guard let lastUsedAt = entry.lastUsedAt else {
            return "未使用"
        }
        return RelativeDateTimeFormatter().localizedString(for: lastUsedAt, relativeTo: Date())
    }

    private var currentProjectName: String {
        viewModel.projects.first(where: { $0.id == viewModel.currentProjectId })?.name ?? "当前项目"
    }

    private var selectionHintText: String {
        if trimmedQuery.isEmpty {
            return "单击选中词条，双击或回车执行；优先显示当前项目和通用项目里最近常用、置顶的词条。"
        }
        return "标题和正文都会参与检索，单击选中后可双击或回车执行。"
    }

    private var trimmedQuery: String {
        viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resultSummaryText: String {
        if trimmedQuery.isEmpty {
            return "\(currentProjectName) · \(viewModel.entries.count) 条可执行词条"
        }
        return "“\(trimmedQuery)” · \(viewModel.entries.count) 条结果"
    }

    private var emptyStateTitle: String {
        trimmedQuery.isEmpty ? "当前项目还没有可执行词条" : "没有找到匹配词条"
    }

    private var emptyStateDescription: String {
        if trimmedQuery.isEmpty {
            return "去主界面新增词条后，这里会立刻可搜可用。"
        }
        return "换个关键词试试，或者去主界面补充更容易命中的标题和内容。"
    }

    private var hotkeyHintText: String {
        if let shortcut = KeyboardShortcuts.Name.togglePanel.shortcut {
            return "\(shortcut)"
        }
        return "未设置快捷键"
    }

    private var panelSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .windowBackgroundColor).opacity(0.96),
                            Color(nsColor: .underPageBackgroundColor).opacity(0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 420
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var sectionSurface: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.06),
                Color.white.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var resultsSurface: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.black.opacity(0.18),
                Color.white.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func emptyStateTip(systemImage: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected
                    ? Color.accentColor.opacity(0.14)
                    : Color.white.opacity(0.035)
            )
    }

    private func rowBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                isSelected ? Color.accentColor.opacity(0.30) : Color.white.opacity(0.08),
                lineWidth: 1
            )
    }

    private var statusIconName: String {
        switch viewModel.statusTone {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private var statusAccentColor: Color {
        switch viewModel.statusTone {
        case .info:
            return .accentColor
        case .warning:
            return Color(red: 0.96, green: 0.71, blue: 0.24)
        case .error:
            return Color(red: 0.88, green: 0.35, blue: 0.35)
        }
    }

    private var statusBackgroundColor: Color {
        switch viewModel.statusTone {
        case .info:
            return Color.accentColor.opacity(0.12)
        case .warning:
            return Color(red: 0.41, green: 0.27, blue: 0.06).opacity(0.34)
        case .error:
            return Color(red: 0.46, green: 0.14, blue: 0.14).opacity(0.34)
        }
    }

    private var statusTitleText: String {
        switch viewModel.statusTone {
        case .info:
            return "状态提示"
        case .warning:
            return "当前为仅复制模式"
        case .error:
            return "操作失败"
        }
    }
}

private enum BadgeTone {
    case accent
    case secondary
}
