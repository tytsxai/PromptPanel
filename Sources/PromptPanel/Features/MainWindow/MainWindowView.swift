import AppKit
import Foundation
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: MainWindowViewModel

    var body: some View {
        ZStack {
            Constants.VisualStyle.surface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                windowHeader

                Group {
                    switch viewModel.selectedTab {
                    case .library:
                        LibraryView(viewModel: viewModel)
                    case .settings:
                        SettingsView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(viewModel.appTheme.preferredColorScheme)
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
        ) { _ in
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

    // MARK: - Header

    private var windowHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Spacer()
                .frame(width: 72) // reserve space for traffic lights

            Spacer(minLength: 0)

            segmentedControl

            Spacer(minLength: 0)

            Text(Constants.appName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(
            Rectangle()
                .fill(Constants.VisualStyle.scrim)
                .overlay(
                    Rectangle()
                        .fill(Constants.VisualStyle.divider)
                        .frame(height: 0.5),
                    alignment: .bottom
                )
        )
    }

    private var segmentedControl: some View {
        HStack(spacing: 2) {
            ForEach(segments, id: \.tab) { segment in
                segmentButton(title: segment.title, tab: segment.tab)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Constants.VisualStyle.tintSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Constants.VisualStyle.border, lineWidth: 0.5)
        )
    }

    private var segments: [(tab: MainWindowViewModel.Tab, title: String)] {
        [
            (.library, "内容库"),
            (.settings, "设置")
        ]
    }

    private func segmentButton(title: String, tab: MainWindowViewModel.Tab) -> some View {
        let isActive = viewModel.selectedTab == tab
        return Button {
            viewModel.selectedTab = tab
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isActive ? Constants.VisualStyle.text : Constants.VisualStyle.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Constants.VisualStyle.tintStrong : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Binding helpers

    private var projectDraftBinding: Binding<MainWindowViewModel.ProjectDraft>? {
        guard viewModel.projectDraft != nil else { return nil }
        return Binding(
            get: { viewModel.projectDraft ?? MainWindowViewModel.ProjectDraft(existingProject: nil) },
            set: { viewModel.projectDraft = $0 }
        )
    }

    private var entryDraftBinding: Binding<MainWindowViewModel.EntryDraft>? {
        guard viewModel.entryDraft != nil else { return nil }
        return Binding(
            get: { viewModel.entryDraft ?? MainWindowViewModel.EntryDraft(existingEntry: nil, defaultProjectId: viewModel.currentProjectId) },
            set: { viewModel.entryDraft = $0 }
        )
    }

    private var deleteProjectBinding: Binding<MainWindowViewModel.ProjectDeletionState>? {
        guard viewModel.deleteProjectState != nil else { return nil }
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
}

// MARK: - Sheets

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
                Button("取消") { dismiss() }
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
                    Text(type.displayName).tag(type.rawValue)
                }
            }

            Toggle("置顶", isOn: $draft.isPinned)

            VStack(alignment: .leading, spacing: 4) {
                Text("标签")
                    .font(.headline)
                TextField("用逗号分隔，例如：发布, 检查清单", text: $draft.tagsText)
                    .textFieldStyle(.roundedBorder)
                Text("短标签用于筛选，保持简洁（每个标签不超过 10 个字）。")
                    .font(.caption)
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
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
                Button("取消") { dismiss() }
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
                .foregroundStyle(Constants.VisualStyle.textSecondary)

            Picker("迁移到", selection: $state.targetProjectId) {
                ForEach(targets) { project in
                    Text(project.name).tag(project.id)
                }
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
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
