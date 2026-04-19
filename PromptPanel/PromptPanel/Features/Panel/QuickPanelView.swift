import KeyboardShortcuts
import SwiftUI

struct QuickPanelView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: QuickPanelViewModel

    var body: some View {
        VStack(spacing: 12) {
            header
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            results
        }
        .padding(16)
        .frame(width: 680, height: 460)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Picker("当前项目", selection: Binding(
                    get: { viewModel.currentProjectId },
                    set: { viewModel.activateProject($0) }
                )) {
                    ForEach(viewModel.projects) { project in
                        Text(project.name).tag(project.id)
                    }
                }
                .labelsHidden()
                .frame(width: 220)

                Spacer()

                Button {
                    viewModel.setPanelPinned(!appState.isPanelPinned)
                } label: {
                    Label(appState.isPanelPinned ? "已固定" : "固定", systemImage: appState.isPanelPinned ? "pin.fill" : "pin")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(appState.isPanelPinned ? "当前面板会持续置顶显示" : "点击后让面板持续置顶显示")

                Text(hotkeyHintText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            .frame(height: 34)
        }
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                            entryRow(entry, index: index)
                                .id(entry.id)
                        }
                    }
                }
                .padding(.vertical, 4)
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("当前没有可执行词条")
                .font(.headline)
            Text("去主界面新增词条后，这里会立即可搜可用。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func entryRow(_ entry: Entry, index: Int) -> some View {
        let isSelected = index == viewModel.selectedIndex

        return Button {
            viewModel.selectEntry(at: index)
            viewModel.executeSelection(force: true, triggerSource: .pointerClick)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if entry.isPinned {
                        labelBadge("置顶")
                    }

                    if shouldShowDefaultBadge(for: entry) {
                        labelBadge("通用")
                    }

                    Spacer()

                    Text(entry.type)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(previewText(for: entry.content))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)

                HStack {
                    if let lastUsedAt = entry.lastUsedAt {
                        Text("最近使用 \(lastUsedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("未使用")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Text("使用 \(entry.useCount)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func shouldShowDefaultBadge(for entry: Entry) -> Bool {
        entry.projectId == appState.defaultProjectId && entry.projectId != viewModel.currentProjectId
    }

    private func labelBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.14)))
            .foregroundStyle(.secondary)
    }

    private func previewText(for content: String) -> String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hotkeyHintText: String {
        if let shortcut = KeyboardShortcuts.Name.togglePanel.shortcut {
            return "\(shortcut) 呼出"
        }
        return "未设置快捷键"
    }
}
