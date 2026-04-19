import AppKit
import Foundation
import SwiftUI

struct QuickPanelView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: QuickPanelViewModel

    var body: some View {
        VStack(spacing: 2) {
            header
            resultsSection

            if let statusMessage = viewModel.statusMessage {
                statusBanner(statusMessage)
            }
        }
        .padding(Constants.PanelLayout.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelSurface)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Constants.PanelLayout.headerSpacing) {
            compactProjectControl

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
            .frame(maxWidth: 720)
            .frame(height: Constants.PanelLayout.controlHeight)
            .layoutPriority(1)

            settingsButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultsSection: some View {
        VStack(spacing: 0) {
            results
                .padding(.horizontal, 1)
                .padding(.vertical, 1)
        }
        .background(resultsSurface)
        .clipShape(RoundedRectangle(cornerRadius: Constants.PanelLayout.sectionCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.PanelLayout.sectionCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.03), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
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
                .padding(.vertical, 0)
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.isLoadingEntries, viewModel.entries.isEmpty == false {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 8)
                        .padding(.trailing, 2)
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
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("正在刷新当前词条…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: Constants.PanelLayout.loadingMinHeight, maxHeight: .infinity)
    }

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: trimmedQuery.isEmpty ? "tray" : "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(emptyStateTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text(emptyStateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Constants.PanelLayout.emptyStateMinHeight, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private func entryRow(_ entry: Entry, index: Int) -> some View {
        let isSelected = index == viewModel.selectedIndex

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.96) : Color.white.opacity(0.90))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if entry.isPinned {
                    labelBadge("置顶", tone: .accent)
                }

                if shouldShowDefaultBadge(for: entry) {
                    labelBadge("通用", tone: .secondary)
                }

                Spacer(minLength: 0)
            }

            Text(previewText(for: entry.content))
                .font(.system(size: 10.5))
                .foregroundStyle(isSelected ? Color.white.opacity(0.72) : Color.white.opacity(0.58))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Constants.PanelLayout.rowHeight)
        .background(rowBackground(isSelected: isSelected))
        .overlay(rowBorder(isSelected: isSelected))
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.86))
                    .frame(width: 3, height: 21)
                    .padding(.leading, 4)
            }
        }
        .overlay(alignment: .bottom) {
            if isSelected == false, index < viewModel.entries.count - 1 {
                Rectangle()
                    .fill(Color.white.opacity(0.075))
                    .frame(height: 1)
                    .padding(.leading, 9)
                    .padding(.trailing, 6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .padding(.horizontal, 5)
            .padding(.vertical, 0)
            .background(
                Capsule()
                    .fill(tone == .accent ? Color.accentColor.opacity(0.10) : Color.white.opacity(0.04))
            )
            .foregroundStyle(tone == .accent ? Color.accentColor.opacity(0.82) : Color.white.opacity(0.56))
    }

    private func statusBanner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: statusIconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusAccentColor)

            Text(statusDisplayMessage(message))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if viewModel.statusTone == .warning {
                Button("打开系统设置") {
                    viewModel.openAccessibilitySettings()
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusAccentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(height: Constants.PanelLayout.statusHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(statusBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(statusAccentColor.opacity(0.20), lineWidth: 1)
        )
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

    private var trimmedQuery: String {
        viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyStateTitle: String {
        if trimmedQuery.isEmpty {
            if viewModel.currentProjectId == appState.defaultProjectId {
                return "当前没有可执行词条"
            }
            return "当前项目和通用内容里都没有可执行词条"
        }
        return "没有找到匹配词条"
    }

    private var emptyStateDescription: String {
        if trimmedQuery.isEmpty {
            if viewModel.currentProjectId == appState.defaultProjectId {
                return "去主界面补充词条后，这里会立刻可搜可用。"
            }
            return "这里会自动带上通用内容；去主界面补充后，这里会立刻可搜可用。"
        }
        return "换个关键词，或去主界面补充更容易命中的标题和内容。"
    }

    private var panelSurface: some View {
        RoundedRectangle(cornerRadius: Constants.PanelLayout.surfaceCornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.PanelLayout.surfaceCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.035), lineWidth: 1)
            )
    }

    private var sectionSurface: some ShapeStyle {
        Color.white.opacity(0.024)
    }

    private var resultsSurface: some ShapeStyle {
        Color.white.opacity(0.016)
    }

    private var compactProjectControl: some View {
        Menu {
            ForEach(viewModel.projects) { project in
                Button {
                    viewModel.activateProject(project.id)
                } label: {
                    HStack(spacing: 8) {
                        Text(project.name)
                        if project.id == appState.defaultProjectId {
                            Text("通用")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(currentProjectName)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: Constants.PanelLayout.projectControlWidth, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(sectionSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("切换当前项目；通用内容会自动一起显示")
    }

    private var currentProjectName: String {
        viewModel.projects.first(where: { $0.id == viewModel.currentProjectId })?.name ?? "未设置"
    }

    private var settingsButton: some View {
        Button {
            viewModel.openSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Constants.PanelLayout.controlHeight, height: Constants.PanelLayout.controlHeight)
                .background(sectionSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("打开设置")
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
            .fill(
                isSelected
                    ? Color.white.opacity(0.08)
                    : Color.clear
            )
    }

    private func rowBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: Constants.Interface.controlCornerRadius, style: .continuous)
            .strokeBorder(
                isSelected ? Color.white.opacity(0.11) : Color.clear,
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
            return Color.accentColor.opacity(0.10)
        case .warning:
            return Color(red: 0.41, green: 0.27, blue: 0.06).opacity(0.26)
        case .error:
            return Color(red: 0.46, green: 0.14, blue: 0.14).opacity(0.26)
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

    private func statusDisplayMessage(_ message: String) -> String {
        switch viewModel.statusTone {
        case .warning:
            return "当前为仅复制模式，已复制但不会自动粘贴。"
        case .info, .error:
            return message
        }
    }
}

private enum BadgeTone {
    case accent
    case secondary
}
