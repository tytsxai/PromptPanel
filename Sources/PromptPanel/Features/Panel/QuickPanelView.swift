import AppKit
import Foundation
import SwiftUI

struct QuickPanelView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: QuickPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .overlay(dividerBottom, alignment: .bottom)

            if let statusMessage = viewModel.statusMessage {
                statusBanner(statusMessage, tone: viewModel.statusTone)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .overlay(dividerBottom, alignment: .bottom)
            }

            resultsList

            if appState.panelShowFooter {
                footerHints
                    .overlay(dividerTop, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(panelSurface)
        .preferredColorScheme(appState.appTheme.preferredColorScheme)
    }

    private var dividerBottom: some View {
        Rectangle()
            .fill(Constants.VisualStyle.divider)
            .frame(height: 0.5)
    }

    private var dividerTop: some View {
        Rectangle()
            .fill(Constants.VisualStyle.divider)
            .frame(height: 0.5)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            projectScope

            Rectangle()
                .fill(Constants.VisualStyle.divider)
                .frame(width: 1, height: 16)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Constants.VisualStyle.textTertiary)

            KeyAwareSearchField(
                text: Binding(
                    get: { viewModel.query },
                    set: { viewModel.query = $0 }
                ),
                placeholder: searchPlaceholder,
                focusToken: viewModel.focusToken,
                onMoveSelection: viewModel.moveSelection,
                onSubmit: { viewModel.executeSelection(triggerSource: .keyboardSubmit) },
                onEscape: viewModel.closePanel,
                onFocusResolved: viewModel.handleSearchFieldFocus,
                onCommandDigit: { digit in
                    viewModel.executeEntry(atNumber: digit)
                    return true
                },
                onCommandCopy: {
                    viewModel.copySelectionOnly()
                    return true
                }
            )
            .id(viewModel.focusToken)
            .frame(maxWidth: .infinity)

            if viewModel.query.isEmpty == false {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
            }

            settingsButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchPlaceholder: String {
        let name = currentProjectName
        return "搜索 \(name) · 输入 # 按标签筛选"
    }

    private var currentProjectName: String {
        viewModel.projects.first(where: { $0.id == viewModel.currentProjectId })?.name ?? "当前项目"
    }

    private var projectScope: some View {
        Menu {
            ForEach(viewModel.projects) { project in
                Button {
                    viewModel.activateProject(project.id)
                } label: {
                    HStack {
                        Text(project.name)
                        if project.id == appState.defaultProjectId {
                            Text("通用")
                                .font(.caption2)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Constants.VisualStyle.textTertiary)
                Text(currentProjectName)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Constants.VisualStyle.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if viewModel.currentProjectId == appState.defaultProjectId {
                    Text("通用")
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
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Constants.VisualStyle.textTertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: Constants.Layout.compactControlHeight)
            .background(
                RoundedRectangle(cornerRadius: Design.pillCornerRadius, style: .continuous)
                    .fill(Constants.VisualStyle.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Design.pillCornerRadius, style: .continuous)
                    .strokeBorder(Constants.VisualStyle.border, lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var settingsButton: some View {
        Button {
            viewModel.openSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Constants.VisualStyle.textTertiary)
                .frame(width: Constants.Layout.compactControlHeight, height: Constants.Layout.compactControlHeight)
        }
        .buttonStyle(.plain)
        .help("打开设置")
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.entries.isEmpty, viewModel.isLoadingEntries {
                        loadingState
                    } else if viewModel.entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                            PanelRow(
                                entry: entry,
                                index: index,
                                isSelected: index == viewModel.selectedIndex,
                                showNumber: viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                showDefaultBadge: shouldShowDefaultBadge(for: entry),
                                isCompact: appState.panelCompactRows,
                                onTap: {
                                    viewModel.selectEntry(at: index)
                                },
                                onDoubleTap: {
                                    viewModel.selectEntry(at: index)
                                    viewModel.executeSelection(force: true, triggerSource: .pointerClick)
                                }
                            )
                            .id(entry.id)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.selectedIndex) { _, _ in
                guard let selectedEntry = viewModel.selectedEntry else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(selectedEntry.id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("正在刷新当前词条…")
                .font(.system(size: 12))
                .foregroundStyle(Constants.VisualStyle.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text(emptyStateTitle)
                .font(.system(size: 12.5))
                .foregroundStyle(Constants.VisualStyle.textTertiary)
            Text(emptyStateSubtitle)
                .font(.system(size: 11))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 72)
        .padding(.vertical, 20)
    }

    private var emptyStateTitle: String {
        viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "当前没有可执行词条"
            : "没有匹配的词条"
    }

    private var emptyStateSubtitle: String {
        viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "去主界面补充词条后，这里会立刻可搜可用。"
            : "换个关键词，或在主界面补充更容易命中的标题和内容。"
    }

    private func shouldShowDefaultBadge(for entry: Entry) -> Bool {
        entry.projectId == appState.defaultProjectId && entry.projectId != viewModel.currentProjectId
    }

    // MARK: - Status banner

    private func statusBanner(_ message: String, tone: QuickPanelViewModel.StatusTone) -> some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon(for: tone))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusAccent(for: tone))
            Text(displayStatusMessage(message, tone: tone))
                .font(.system(size: 11.5))
                .foregroundStyle(Constants.VisualStyle.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if tone == .warning {
                Button("前往授权") {
                    viewModel.openAccessibilitySettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(statusAccent(for: tone))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Rectangle()
                .fill(statusBackground(for: tone))
        )
        .overlay(
            Rectangle()
                .fill(statusBorder(for: tone))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private func displayStatusMessage(_ message: String, tone: QuickPanelViewModel.StatusTone) -> String {
        switch tone {
        case .warning:
            return message
        case .info, .error:
            return message
        }
    }

    private func statusIcon(for tone: QuickPanelViewModel.StatusTone) -> String {
        switch tone {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "exclamationmark.octagon.fill"
        }
    }

    private func statusAccent(for tone: QuickPanelViewModel.StatusTone) -> Color {
        switch tone {
        case .info:
            return Constants.VisualStyle.accent
        case .warning:
            return Constants.VisualStyle.warn
        case .error:
            return Constants.VisualStyle.danger
        }
    }

    private func statusBackground(for tone: QuickPanelViewModel.StatusTone) -> Color {
        switch tone {
        case .info:
            return Constants.VisualStyle.accentDim
        case .warning:
            return Constants.VisualStyle.warnDim
        case .error:
            return Constants.VisualStyle.dangerDim
        }
    }

    private func statusBorder(for tone: QuickPanelViewModel.StatusTone) -> Color {
        statusAccent(for: tone).opacity(0.25)
    }

    // MARK: - Footer

    private var footerHints: some View {
        HStack(spacing: 12) {
            hint(keys: "↑↓", label: "选择")
            hint(keys: "Enter", label: "执行")
            hint(keys: "Esc", label: "关闭")
            hint(keys: "⌘C", label: "复制")
            hint(keys: "⌘1-9", label: "直达")
            Spacer(minLength: 0)
            Text("\(viewModel.entries.count) 条")
                .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
        }
        .padding(.horizontal, 12)
        .frame(height: Constants.Layout.footerHeight)
        .background(Constants.VisualStyle.scrim)
    }

    private func hint(keys: String, label: String) -> some View {
        HStack(spacing: 4) {
            KbdLabel(text: keys)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(Constants.VisualStyle.textTertiary)
        }
    }

    private var panelSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Constants.VisualStyle.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Constants.VisualStyle.borderStrong, lineWidth: 0.5)
            )
    }
}

private struct PanelRow: View {
    let entry: Entry
    let index: Int
    let isSelected: Bool
    let showNumber: Bool
    let showDefaultBadge: Bool
    let isCompact: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        let type = Constants.EntryType.resolve(entry.type)
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(numberText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? Constants.VisualStyle.accent : Constants.VisualStyle.textQuaternary)
                    .frame(width: 16, alignment: .center)

                Image(systemName: type.symbolName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Constants.VisualStyle.text : Constants.VisualStyle.textSecondary)
                    .frame(width: 16, height: 16)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    HStack(spacing: 5) {
                        Text(entry.title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Constants.VisualStyle.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Constants.VisualStyle.warn.opacity(0.85))
                        }
                    }
                    .layoutPriority(1)
                    .frame(maxWidth: 220, alignment: .leading)

                    Text(previewText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    if isSelected {
                        Text("\(entry.useCount) 次")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Constants.VisualStyle.textQuaternary)
                    }
                    if showDefaultBadge {
                        Text("通用")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Constants.VisualStyle.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: Constants.Layout.badgeCornerRadius, style: .continuous)
                                    .fill(Constants.VisualStyle.tintSubtle)
                            )
                    }
                    Text(type.displayName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(isSelected ? Constants.VisualStyle.textSecondary : Constants.VisualStyle.textQuaternary)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: isCompact ? Constants.Layout.compactRowHeight : Constants.Layout.regularRowHeight)
            .background(
                RoundedRectangle(cornerRadius: Design.rowCornerRadius, style: .continuous)
                    .fill(isSelected ? Constants.VisualStyle.tintSubtle : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: Design.rowCornerRadius, style: .continuous))
        .simultaneousGesture(TapGesture(count: 2).onEnded { _ in
            onDoubleTap()
        })
    }

    private var numberText: String {
        showNumber && index < 9 ? "\(index + 1)" : ""
    }

    private var previewText: String {
        entry.content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}
