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
            scheduleEntriesRefresh(delayMs: Constants.panelSearchDebounceMs)
        }
    }
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var projects: [Project] = []
    @Published var currentProjectId: String = ""
    @Published var selectedIndex: Int = 0
    @Published var focusToken: Int = 0
    @Published var statusMessage: String?
    private(set) var isExecutionReady: Bool = false

    private let appState: AppState
    private let projectRepository: ProjectRepository
    private let settingsRepository: SettingsRepository
    private let searchService: EntrySearchService
    private let executeService: ExecuteService
    private let permissionService: PermissionService
    private let panelOpenTracker: PanelOpenTracker?
    private let onClosePanel: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private let searchQueue = DispatchQueue(label: "PromptPanel.quick-panel.search", qos: .userInitiated)
    private var pendingSearchWorkItem: DispatchWorkItem?
    private var searchGeneration: Int = 0

    init(
        appState: AppState,
        projectRepository: ProjectRepository,
        settingsRepository: SettingsRepository,
        searchService: EntrySearchService,
        executeService: ExecuteService,
        permissionService: PermissionService,
        panelOpenTracker: PanelOpenTracker? = nil,
        onClosePanel: @escaping () -> Void
    ) {
        self.appState = appState
        self.projectRepository = projectRepository
        self.settingsRepository = settingsRepository
        self.searchService = searchService
        self.executeService = executeService
        self.permissionService = permissionService
        self.panelOpenTracker = panelOpenTracker
        self.onClosePanel = onClosePanel
        self.currentProjectId = appState.effectiveProjectId

        observeChanges()
    }

    deinit {
        pendingSearchWorkItem?.cancel()
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
        isExecutionReady = false
        focusToken += 1
        loadProjects()
        scheduleEntriesRefresh(delayMs: 0)
    }

    func handleSearchFieldFocus(_ result: PanelFocusResult) {
        guard result.token == focusToken else {
            return
        }
        panelOpenTracker?.markSearchFieldFocused(result)
        guard result.succeeded else {
            isExecutionReady = false
            return
        }
        scheduleExecutionUnlock(for: result.token)
    }

    func retryFocusAfterActivationStabilized() {
        isExecutionReady = false
        focusToken += 1
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

    func executeSelection(force: Bool = false) {
        guard force || isExecutionReady else {
            PPLogger.panel.warning("Ignored executeSelection because panel is not ready for execution yet")
            return
        }
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
            scheduleEntriesRefresh(delayMs: 0)
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
                self?.scheduleEntriesRefresh(delayMs: 0)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .entriesDidChange)
            .sink { [weak self] _ in
                self?.scheduleEntriesRefresh(delayMs: 0)
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

    private func scheduleEntriesRefresh(delayMs: Int) {
        pendingSearchWorkItem?.cancel()
        entries = []
        selectedIndex = 0

        guard !appState.effectiveProjectId.isEmpty || !currentProjectId.isEmpty else {
            return
        }

        let effectiveCurrentProjectId = currentProjectId.isEmpty ? appState.effectiveProjectId : currentProjectId
        let defaultProjectId = appState.defaultProjectId
        let query = self.query
        let searchService = self.searchService

        appState.currentProjectId = effectiveCurrentProjectId
        searchGeneration += 1
        let generation = searchGeneration

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.searchQueue.async { [weak self] in
                guard let self else {
                    return
                }

                let result: Result<[Entry], Error>
                do {
                    result = .success(
                        try searchService.search(
                            query: query,
                            currentProjectId: effectiveCurrentProjectId,
                            defaultProjectId: defaultProjectId
                        )
                    )
                } catch {
                    result = .failure(error)
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self, self.searchGeneration == generation else {
                        return
                    }

                    switch result {
                    case .success(let entries):
                        self.entries = entries
                        if entries.isEmpty {
                            self.selectedIndex = 0
                        } else {
                            self.selectedIndex = min(self.selectedIndex, entries.count - 1)
                        }
                    case .failure(let error):
                        PPLogger.search.error("Panel search failed: \(error.localizedDescription)")
                        self.entries = []
                        self.selectedIndex = 0
                        self.statusMessage = "搜索失败，请稍后重试。"
                    }
                }
            }
        }

        pendingSearchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(delayMs, 0)), execute: workItem)
    }

    private func scheduleExecutionUnlock(for token: Int) {
        isExecutionReady = false
        let delay = Double(Constants.panelExecutionUnlockDelayMs) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else {
                return
            }
            guard self.focusToken == token else {
                return
            }
            self.isExecutionReady = true
        }
    }
}
