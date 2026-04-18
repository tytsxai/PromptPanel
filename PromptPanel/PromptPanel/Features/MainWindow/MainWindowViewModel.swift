import Combine
import Foundation

@MainActor
final class MainWindowViewModel: ObservableObject {
    static let allProjectsSelection = "__all_projects__"

    struct ProjectDraft: Identifiable {
        let id: String
        let existingProject: Project?
        var name: String

        init(existingProject: Project?) {
            self.id = existingProject?.id ?? UUID().uuidString
            self.existingProject = existingProject
            self.name = existingProject?.name ?? ""
        }
    }

    struct ProjectDeletionState: Identifiable {
        let id: String
        let project: Project
        let entryCount: Int
        var targetProjectId: String

        init(project: Project, entryCount: Int, targetProjectId: String) {
            self.id = project.id
            self.project = project
            self.entryCount = entryCount
            self.targetProjectId = targetProjectId
        }
    }

    struct EntryDraft: Identifiable {
        let id: String
        let existingEntry: Entry?
        var title: String
        var content: String
        var projectId: String
        var type: String
        var isPinned: Bool
        var sortOrder: Int

        init(existingEntry: Entry?, defaultProjectId: String) {
            self.id = existingEntry?.id ?? UUID().uuidString
            self.existingEntry = existingEntry
            self.title = existingEntry?.title ?? ""
            self.content = existingEntry?.content ?? ""
            self.projectId = existingEntry?.projectId ?? defaultProjectId
            self.type = existingEntry?.type ?? Constants.EntryType.prompt.rawValue
            self.isPinned = existingEntry?.isPinned ?? false
            self.sortOrder = existingEntry?.sortOrder ?? 0
        }
    }

    @Published private(set) var projects: [Project] = []
    @Published private(set) var entries: [Entry] = []
    @Published var selectedProjectId: String = MainWindowViewModel.allProjectsSelection {
        didSet {
            refreshEntries()
        }
    }
    @Published var entrySearchText: String = "" {
        didSet {
            refreshEntries()
        }
    }
    @Published var projectDraft: ProjectDraft?
    @Published var entryDraft: EntryDraft?
    @Published var deleteProjectState: ProjectDeletionState?
    @Published var entryPendingDeletion: Entry?
    @Published var hasAccessibilityPermission: Bool = false
    @Published var launchAtLoginEnabled: Bool = false
    @Published var bannerMessage: String?

    private let appState: AppState
    private let projectRepository: ProjectRepository
    private let entryRepository: EntryRepository
    private let settingsRepository: SettingsRepository
    private let permissionService: PermissionService
    private let loginItemService: LoginItemService
    private var cancellables = Set<AnyCancellable>()

    init(
        appState: AppState,
        projectRepository: ProjectRepository,
        entryRepository: EntryRepository,
        settingsRepository: SettingsRepository,
        permissionService: PermissionService,
        loginItemService: LoginItemService
    ) {
        self.appState = appState
        self.projectRepository = projectRepository
        self.entryRepository = entryRepository
        self.settingsRepository = settingsRepository
        self.permissionService = permissionService
        self.loginItemService = loginItemService

        observeChanges()
    }

    var currentProjectId: String {
        appState.effectiveProjectId
    }

    var selectedProject: Project? {
        projects.first(where: { $0.id == selectedProjectId })
    }

    var projectOptions: [Project] {
        projects
    }

    func load() {
        refreshPermissionState()
        loadProjects()
        loadEntries()
    }

    func refreshPermissionState() {
        permissionService.refresh()
        hasAccessibilityPermission = permissionService.isAccessibilityGranted
        launchAtLoginEnabled = loginItemService.isEnabled
    }

    func requestAccessibilityPermission() {
        permissionService.requestPermission()
        refreshPermissionState()
        bannerMessage = permissionService.isAccessibilityGranted ? "辅助功能权限已启用。" : "权限尚未完成，请在系统设置中继续授权。"
    }

    func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            loginItemService.enable()
        } else {
            loginItemService.disable()
        }
        launchAtLoginEnabled = loginItemService.isEnabled
    }

    func setCurrentProjectToSelected() {
        guard let project = selectedProject else {
            bannerMessage = "请先选择一个具体项目。"
            return
        }
        persistCurrentProject(project.id)
        bannerMessage = "当前项目已切换为 \(project.name)。"
    }

    func startCreateProject() {
        projectDraft = ProjectDraft(existingProject: nil)
    }

    func startRenameSelectedProject() {
        guard let project = selectedProject else {
            bannerMessage = "请先选择要重命名的项目。"
            return
        }
        projectDraft = ProjectDraft(existingProject: project)
    }

    func saveProjectDraft() -> Bool {
        guard var draft = projectDraft else {
            return false
        }

        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.name.isEmpty else {
            bannerMessage = "项目名称不能为空。"
            return false
        }

        do {
            if let existingProject = draft.existingProject {
                try projectRepository.rename(id: existingProject.id, newName: draft.name)
                bannerMessage = "项目已重命名。"
            } else {
                let project = Project(name: draft.name)
                try projectRepository.create(project)
                selectedProjectId = project.id
                bannerMessage = "项目已创建。"
            }

            projectDraft = nil
            notifyProjectsChanged()
            return true
        } catch {
            PPLogger.project.error("Failed to save project draft: \(error.localizedDescription)")
            bannerMessage = "保存项目失败，请重试。"
            return false
        }
    }

    func requestDeleteSelectedProject() {
        guard let project = selectedProject else {
            bannerMessage = "请先选择要删除的项目。"
            return
        }
        guard !project.isDefault else {
            bannerMessage = "通用项目不能删除。"
            return
        }

        do {
            let entryCount = try projectRepository.entryCount(forProjectId: project.id)
            if entryCount == 0 {
                try projectRepository.delete(id: project.id)
                handleProjectDeletionFallback(deletedProjectId: project.id, replacementProjectId: appState.defaultProjectId)
                notifyProjectsChanged()
                bannerMessage = "项目已删除。"
            } else if let targetProjectId = projects.first(where: { $0.id != project.id })?.id {
                deleteProjectState = ProjectDeletionState(
                    project: project,
                    entryCount: entryCount,
                    targetProjectId: targetProjectId
                )
            }
        } catch {
            PPLogger.project.error("Failed to request project deletion: \(error.localizedDescription)")
            bannerMessage = "删除项目失败，请重试。"
        }
    }

    func confirmDeleteProject() -> Bool {
        guard let state = deleteProjectState else {
            return false
        }

        do {
            try projectRepository.migrateAndDelete(fromId: state.project.id, toId: state.targetProjectId)
            handleProjectDeletionFallback(deletedProjectId: state.project.id, replacementProjectId: state.targetProjectId)
            deleteProjectState = nil
            notifyProjectsChanged()
            NotificationCenter.default.post(name: .entriesDidChange, object: nil)
            bannerMessage = "项目已删除，词条已迁移。"
            return true
        } catch {
            PPLogger.project.error("Failed to migrate and delete project: \(error.localizedDescription)")
            bannerMessage = "项目迁移删除失败，请重试。"
            return false
        }
    }

    func startCreateEntry() {
        let defaultProjectId = selectedProjectId == Self.allProjectsSelection ? currentProjectId : selectedProjectId
        entryDraft = EntryDraft(existingEntry: nil, defaultProjectId: defaultProjectId)
    }

    func startEditEntry(_ entry: Entry) {
        entryDraft = EntryDraft(existingEntry: entry, defaultProjectId: entry.projectId)
    }

    func saveEntryDraft() -> Bool {
        guard let draft = entryDraft else {
            return false
        }

        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else {
            bannerMessage = "词条标题和内容都不能为空。"
            return false
        }

        do {
            if let existingEntry = draft.existingEntry {
                let updated = Entry(
                    id: existingEntry.id,
                    projectId: draft.projectId,
                    title: trimmedTitle,
                    content: draft.content,
                    type: draft.type,
                    isPinned: draft.isPinned,
                    sortOrder: draft.sortOrder,
                    useCount: existingEntry.useCount,
                    lastUsedAt: existingEntry.lastUsedAt,
                    createdAt: existingEntry.createdAt,
                    updatedAt: Date()
                )
                try entryRepository.update(updated)
                bannerMessage = "词条已更新。"
            } else {
                let entry = Entry(
                    projectId: draft.projectId,
                    title: trimmedTitle,
                    content: draft.content,
                    type: draft.type,
                    isPinned: draft.isPinned,
                    sortOrder: draft.sortOrder
                )
                try entryRepository.create(entry)
                bannerMessage = "词条已创建。"
            }

            entryDraft = nil
            NotificationCenter.default.post(name: .entriesDidChange, object: nil)
            return true
        } catch {
            PPLogger.entry.error("Failed to save entry draft: \(error.localizedDescription)")
            bannerMessage = "保存词条失败，请重试。"
            return false
        }
    }

    func requestDeleteEntry(_ entry: Entry) {
        entryPendingDeletion = entry
    }

    func confirmDeleteEntry() {
        guard let entry = entryPendingDeletion else {
            return
        }

        do {
            try entryRepository.delete(id: entry.id)
            entryPendingDeletion = nil
            NotificationCenter.default.post(name: .entriesDidChange, object: nil)
            bannerMessage = "词条已删除。"
        } catch {
            PPLogger.entry.error("Failed to delete entry: \(error.localizedDescription)")
            bannerMessage = "删除词条失败，请重试。"
        }
    }

    private func observeChanges() {
        NotificationCenter.default.publisher(for: .projectsDidChange)
            .sink { [weak self] _ in
                self?.loadProjects()
                self?.loadEntries()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .entriesDidChange)
            .sink { [weak self] _ in
                self?.loadEntries()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .currentProjectDidChange)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func notifyProjectsChanged() {
        NotificationCenter.default.post(name: .projectsDidChange, object: nil)
    }

    private func loadProjects() {
        do {
            projects = try projectRepository.fetchAll()
            if selectedProjectId == Self.allProjectsSelection {
                return
            }
            if !projects.contains(where: { $0.id == selectedProjectId }) {
                selectedProjectId = appState.effectiveProjectId.isEmpty ? Self.allProjectsSelection : appState.effectiveProjectId
            }
        } catch {
            PPLogger.project.error("Failed to load projects: \(error.localizedDescription)")
            projects = []
            selectedProjectId = Self.allProjectsSelection
            bannerMessage = "加载项目列表失败。"
        }
    }

    private func loadEntries() {
        refreshEntries()
    }

    private func refreshEntries() {
        do {
            if selectedProjectId == Self.allProjectsSelection {
                if entrySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    entries = try entryRepository.fetchAll()
                } else {
                    entries = try entryRepository.search(
                        query: entrySearchText,
                        projectIds: projects.map(\.id)
                    )
                }
            } else if entrySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                entries = try entryRepository.fetchByProject(selectedProjectId)
            } else {
                entries = try entryRepository.search(
                    query: entrySearchText,
                    projectIds: [selectedProjectId]
                )
            }
        } catch {
            PPLogger.entry.error("Failed to load entries: \(error.localizedDescription)")
            entries = []
            bannerMessage = "加载词条失败。"
        }
    }

    private func persistCurrentProject(_ projectId: String?) {
        guard let projectId else {
            return
        }

        do {
            try settingsRepository.setCurrentProjectId(projectId)
            appState.currentProjectId = projectId
            NotificationCenter.default.post(name: .currentProjectDidChange, object: nil)
        } catch {
            PPLogger.project.error("Failed to persist current project: \(error.localizedDescription)")
            bannerMessage = "切换当前项目失败，请重试。"
        }
    }

    private func handleProjectDeletionFallback(deletedProjectId: String, replacementProjectId: String?) {
        if selectedProjectId == deletedProjectId {
            selectedProjectId = replacementProjectId ?? Self.allProjectsSelection
        }

        if appState.currentProjectId == deletedProjectId || appState.effectiveProjectId == deletedProjectId {
            persistCurrentProject(replacementProjectId ?? appState.defaultProjectId)
        }
    }
}
