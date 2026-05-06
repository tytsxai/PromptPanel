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
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Constants.VisualStyle.textQuaternary)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: Constants.Layout.headerHeight)
        .background(
            Rectangle()
                .fill(Constants.VisualStyle.surface)
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
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Constants.VisualStyle.tintMedium : Color.clear)
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
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: draft.existingProject == nil ? "新建项目" : "重命名项目")

            VStack(alignment: .leading, spacing: 10) {
                SheetField(label: "项目名称") {
                    TextField("项目名称", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .focused($isNameFocused)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            SheetActionFooter(
                primaryTitle: "保存",
                canSubmit: isProjectDraftValid,
                message: isProjectDraftValid ? nil : "项目名称不能为空。",
                onCancel: { dismiss() },
                onPrimary: saveAndDismiss
            )
        }
        .frame(width: 420)
        .onAppear { isNameFocused = true }
    }

    private var isProjectDraftValid: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func saveAndDismiss() {
        guard isProjectDraftValid else { return }
        if onSave() {
            dismiss()
        }
    }
}

private struct EntryEditorSheet: View {
    @Binding var draft: MainWindowViewModel.EntryDraft
    let projects: [Project]
    let onSave: () -> Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case title
        case content
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: draft.existingEntry == nil ? "新建词条" : "编辑词条")

            VStack(alignment: .leading, spacing: 14) {
                SheetField(label: "标题") {
                    TextField("给这条内容起个短标题", text: $draft.title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .focused($focusedField, equals: .title)
                }

                HStack(alignment: .top, spacing: 14) {
                    SheetField(label: "所属项目") {
                        Picker("", selection: $draft.projectId) {
                            ForEach(projects) { project in
                                Text(project.name).tag(project.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 176, alignment: .leading)
                        .fixedSize()
                    }

                    SheetField(label: "类型") {
                        Picker("", selection: $draft.type) {
                            ForEach(Constants.EntryType.allCases, id: \.rawValue) { type in
                                Text(type.displayName).tag(type.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 132, alignment: .leading)
                        .fixedSize()
                    }

                    Toggle(isOn: $draft.isPinned) {
                        Text("置顶")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .toggleStyle(.checkbox)
                    .padding(.top, 23)

                    Spacer(minLength: 0)
                }

                SheetField(
                    label: "标签",
                    footer: "短标签用于筛选，保持简洁（每个标签不超过 10 个字）。"
                ) {
                    TextField("用逗号分隔，例如：发布, 检查清单", text: $draft.tagsText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                contentEditor
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            SheetActionFooter(
                primaryTitle: "保存",
                canSubmit: isEntryDraftValid,
                message: isEntryDraftValid ? nil : "标题和内容都填完后才能保存。",
                onCancel: { dismiss() },
                onPrimary: saveAndDismiss
            )
        }
        .frame(width: 620)
        .onAppear {
            focusedField = draft.title.isEmpty ? .title : .content
        }
    }

    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SheetFieldLabel(text: "内容")
                Spacer(minLength: 0)
                Text("\(draft.content.count) 字")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Constants.VisualStyle.textQuaternary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft.content)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .background(Constants.VisualStyle.surface)
                    .focused($focusedField, equals: .content)

                if draft.content.isEmpty {
                    Text("粘贴或输入要执行的内容")
                        .font(.system(size: 13))
                        .foregroundStyle(Constants.VisualStyle.textQuaternary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 230)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Constants.VisualStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(contentBorderColor, lineWidth: focusedField == .content ? 1 : 0.5)
            )
        }
    }

    private var contentBorderColor: Color {
        focusedField == .content ? Constants.VisualStyle.accentBorder : Constants.VisualStyle.borderStrong
    }

    private var isEntryDraftValid: Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func saveAndDismiss() {
        guard isEntryDraftValid else { return }
        if onSave() {
            dismiss()
        }
    }
}

private struct ProjectMigrationSheet: View {
    @Binding var state: MainWindowViewModel.ProjectDeletionState
    let targets: [Project]
    let onConfirm: () -> Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "删除前先迁移词条")

            VStack(alignment: .leading, spacing: 14) {
                Text("项目 “\(state.project.name)” 下还有 \(state.entryCount) 条词条，必须先迁移到其他项目。")
                    .font(.system(size: 13))
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                SheetField(label: "迁移到") {
                    Picker("", selection: $state.targetProjectId) {
                        ForEach(targets) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            SheetActionFooter(
                primaryTitle: "迁移并删除",
                primaryRole: .destructive,
                canSubmit: state.targetProjectId.isEmpty == false,
                onCancel: { dismiss() },
                onPrimary: confirmAndDismiss
            )
        }
        .frame(width: 460)
    }

    private func confirmAndDismiss() {
        guard state.targetProjectId.isEmpty == false else { return }
        if onConfirm() {
            dismiss()
        }
    }
}

private struct SheetHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Constants.VisualStyle.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background(Constants.VisualStyle.surfaceRaised)
            .overlay(
                Rectangle()
                    .fill(Constants.VisualStyle.divider)
                    .frame(height: 0.5),
                alignment: .bottom
            )
    }
}

private struct SheetField<Content: View>: View {
    let label: String
    let footer: String?
    let content: () -> Content

    init(label: String, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SheetFieldLabel(text: label)
            content()
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SheetFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Constants.VisualStyle.text)
    }
}

private struct SheetActionFooter: View {
    let primaryTitle: String
    var primaryRole: ButtonRole?
    let canSubmit: Bool
    var message: String?
    let onCancel: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let message {
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Constants.VisualStyle.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("取消", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .frame(minWidth: 72)

            Button(role: primaryRole, action: onPrimary) {
                Text(primaryTitle)
                    .frame(minWidth: 72)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
        }
        .controlSize(.regular)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Constants.VisualStyle.surfaceRaised)
        .overlay(
            Rectangle()
                .fill(Constants.VisualStyle.divider)
                .frame(height: 0.5),
            alignment: .top
        )
    }
}
