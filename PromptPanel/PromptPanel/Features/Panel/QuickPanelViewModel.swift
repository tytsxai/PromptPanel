import Combine
import Foundation

@MainActor
final class QuickPanelViewModel: ObservableObject {
    enum SelectionDirection {
        case up
        case down
    }

    @Published var query: String = "" {
        didSet {
            refreshEntries()
        }
    }
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var projects: [Project] = []
    @Published var currentProjectId: String = ""
    @Published var selectedIndex: Int = 0
    @Published var focusToken: Int = 0
    @Published var statusMessage: String?

    private let appState: AppState
    private let projectRepository: ProjectRepository
    private let settingsRepository: SettingsRepository
    private let searchService: EntrySearchService
    private let executeService: ExecuteService
    private let permissionService: PermissionService
    private let onClosePanel: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        appState: AppState,
        projectRepository: ProjectRepository,
        settingsRepository: SettingsRepository,
        searchService: EntrySearchService,
        executeService: ExecuteService,
        permissionService: PermissionService,
        onClosePanel: @escaping () -> Void
    ) {
        self.appState = appState
        self.projectRepository = projectRepository
        self.settingsRepository = settingsRepository
        self.searchService = searchService
        self.executeService = executeService
        self.permissionService = permissionService
        self.onClosePanel = onClosePanel
        self.currentProjectId = appState.effectiveProjectId

        observeChanges()
    }

    var selectedEntry: Entry? {
        guard entries.indices.contains(selectedIndex) else {
            return entries.first
        }
        return entries[selectedIndex]
    }

    func prepareForPresentation() {
        permissionService.refresh()
        statusMessage = permissionService.isAccessibilityGranted ? nil : "当前为仅复制模式，授权后可恢复自动粘贴。"
        query = ""
        selectedIndex = 0
        currentProjectId = appState.effectiveProjectId
        focusToken += 1
        loadProjects()
        refreshEntries()
    }

    func closePanel() {
        onClosePanel()
    }

    func moveSelection(_ direction: SelectionDirection) {
        guard !entries.isEmpty else {
            return
        }

        switch direction {
        case .up:
            selectedIndex = max(0, selectedIndex - 1)
        case .down:
            selectedIndex = min(entries.count - 1, selectedIndex + 1)
        }
    }

    func selectEntry(at index: Int) {
        guard entries.indices.contains(index) else {
            return
        }
        selectedIndex = index
    }

    func executeSelection() {
        guard let entry = selectedEntry else {
            return
        }

        executeService.execute(entry: entry, currentProjectId: currentProjectId)
    }

    func activateProject(_ id: String) {
        guard !id.isEmpty, currentProjectId != id else {
            return
        }

        do {
            try settingsRepository.setCurrentProjectId(id)
            appState.currentProjectId = id
            currentProjectId = id
            NotificationCenter.default.post(name: .currentProjectDidChange, object: nil)
            refreshEntries()
        } catch {
            PPLogger.project.error("Failed to switch current project: \(error.localizedDescription)")
            statusMessage = "切换项目失败，请重试。"
        }
    }

    private func observeChanges() {
        NotificationCenter.default.publisher(for: .projectsDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .currentProjectDidChange))
            .sink { [weak self] _ in
                self?.loadProjects()
                self?.refreshEntries()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .entriesDidChange)
            .sink { [weak self] _ in
                self?.refreshEntries()
            }
            .store(in: &cancellables)
    }

    private func loadProjects() {
        do {
            projects = try projectRepository.fetchAll()
            if currentProjectId.isEmpty || !projects.contains(where: { $0.id == currentProjectId }) {
                currentProjectId = appState.effectiveProjectId
            }
        } catch {
            PPLogger.project.error("Failed to load projects for panel: \(error.localizedDescription)")
            projects = []
            statusMessage = "加载项目失败，请重试。"
        }
    }

    private func refreshEntries() {
        guard !appState.effectiveProjectId.isEmpty || !currentProjectId.isEmpty else {
            entries = []
            selectedIndex = 0
            return
        }

        appState.currentProjectId = currentProjectId.isEmpty ? appState.effectiveProjectId : currentProjectId

        do {
            entries = try searchService.search(query: query)
            if entries.isEmpty {
                selectedIndex = 0
            } else {
                selectedIndex = min(selectedIndex, entries.count - 1)
            }
        } catch {
            PPLogger.search.error("Panel search failed: \(error.localizedDescription)")
            entries = []
            selectedIndex = 0
            statusMessage = "搜索失败，请稍后重试。"
        }
    }
}
