import Foundation
@testable import PromptPanel
import KeyboardShortcuts

#if canImport(XCTest)
import XCTest

final class PromptPanelTests: XCTestCase {
    func testConstantsExist() {
        XCTAssertEqual(Constants.appName, "PromptPanel")
        XCTAssertEqual(Constants.bundleIdentifier, "com.promptpanel.app")
        XCTAssertEqual(Constants.defaultProjectName, "通用项目")
    }

    func testDatabaseSeedsDefaultProjectAndCurrentProject() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)

        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        XCTAssertEqual(defaultProject.name, Constants.defaultProjectName)
        XCTAssertEqual(try settingsRepository.getCurrentProjectId(), defaultProject.id)
    }

    func testMixedEntriesPreferCurrentProjectWhenSortKeysEqual() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let currentProject = Project(name: "Current")
        try projectRepository.create(currentProject)

        let now = Date()
        try entryRepository.create(
            Entry(
                projectId: defaultProject.id,
                title: "共享标题",
                content: "通用内容",
                sortOrder: 10,
                useCount: 4,
                lastUsedAt: now,
                createdAt: now,
                updatedAt: now
            )
        )
        try entryRepository.create(
            Entry(
                projectId: currentProject.id,
                title: "共享标题",
                content: "当前内容",
                sortOrder: 10,
                useCount: 4,
                lastUsedAt: now,
                createdAt: now,
                updatedAt: now
            )
        )

        let result = try entryRepository.fetchMixed(
            currentProjectId: currentProject.id,
            defaultProjectId: defaultProject.id
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.projectId, currentProject.id)
        XCTAssertEqual(result.last?.projectId, defaultProject.id)
    }

    func testMigrateAndDeleteMovesEntriesToTargetProject() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

        let sourceProject = Project(name: "Source")
        let targetProject = Project(name: "Target")
        try projectRepository.create(sourceProject)
        try projectRepository.create(targetProject)

        let entry = Entry(projectId: sourceProject.id, title: "Snippet", content: "echo hello")
        try entryRepository.create(entry)

        try projectRepository.migrateAndDelete(fromId: sourceProject.id, toId: targetProject.id)

        XCTAssertNil(try projectRepository.fetchById(sourceProject.id))
        let migratedEntry = try XCTUnwrap(entryRepository.fetchById(entry.id))
        XCTAssertEqual(migratedEntry.projectId, targetProject.id)
    }

    func testExecutionLogPersistsFailureReasonAndDiagnostics() throws {
        let databaseManager = try makeDatabaseManager()
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)

        let log = ExecutionLog(
            entryId: "entry-1",
            projectId: "project-1",
            frontAppBundleId: "com.apple.Safari",
            observedAppBundleId: Bundle.main.bundleIdentifier,
            hasAccessibility: true,
            clipboardSuccess: true,
            pasteAttempted: false,
            pasteSuccess: false,
            result: Constants.ExecutionResult.clipboardOnly.rawValue,
            failureReason: Constants.ExecutionFailureReason.targetAppNotRestored.rawValue,
            totalDurationMs: 143
        )

        try logRepository.record(log)
        let recentLogs = try logRepository.fetchRecent(limit: 10)
        let persisted = try XCTUnwrap(recentLogs.first)

        XCTAssertEqual(persisted.failureReason, Constants.ExecutionFailureReason.targetAppNotRestored.rawValue)
        XCTAssertEqual(persisted.totalDurationMs, 143)
        XCTAssertEqual(persisted.observedAppBundleId, Bundle.main.bundleIdentifier)
    }

    @MainActor
    func testHotkeyServiceInvokesToggleAndStartsTrace() {
        let registrar = FakeHotkeyRegistrar()
        let tracker = PanelOpenTracker()
        var toggleCount = 0

        let service = HotkeyService(
            onTogglePanel: { toggleCount += 1 },
            registrar: registrar,
            panelOpenTracker: tracker
        )

        service.start()
        registrar.trigger(.togglePanel)

        XCTAssertEqual(toggleCount, 1)
        XCTAssertNotNil(tracker.currentTrace)
    }

    @MainActor
    func testQuickPanelPrepareForPresentationResetsStateAndRequestsFocus() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let permissionService = PermissionService()
        let appState = AppState()
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        appState.loadPersistedState(currentProjectId: defaultProject.id, defaultProjectId: defaultProject.id)

        let currentProject = Project(name: "Current")
        try projectRepository.create(currentProject)
        try settingsRepository.setCurrentProjectId(currentProject.id)
        appState.currentProjectId = currentProject.id

        let executeService = ExecuteService(
            clipboardService: ClipboardService(),
            pasteService: PasteService(),
            entryRepository: entryRepository,
            logRepository: logRepository,
            permissionService: permissionService,
            targetApplicationProvider: { nil },
            currentFrontApplicationProvider: { nil }
        )

        let viewModel = QuickPanelViewModel(
            appState: appState,
            projectRepository: projectRepository,
            settingsRepository: settingsRepository,
            searchService: EntrySearchService(entryRepository: entryRepository, appState: appState),
            executeService: executeService,
            permissionService: permissionService,
            panelOpenTracker: PanelOpenTracker(),
            onClosePanel: {}
        )

        viewModel.query = "old-query"
        viewModel.selectedIndex = 4
        let previousFocusToken = viewModel.focusToken

        viewModel.prepareForPresentation()

        XCTAssertEqual(viewModel.query, "")
        XCTAssertEqual(viewModel.selectedIndex, 0)
        XCTAssertEqual(viewModel.currentProjectId, currentProject.id)
        XCTAssertEqual(viewModel.focusToken, previousFocusToken + 1)
        XCTAssertFalse(viewModel.isExecutionReady)
        XCTAssertFalse(viewModel.projectOptions.isEmpty)
    }

    @MainActor
    func testQuickPanelExecutionUnlocksAfterFocusResolution() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let permissionService = PermissionService()
        let appState = AppState()
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        appState.loadPersistedState(currentProjectId: defaultProject.id, defaultProjectId: defaultProject.id)

        let executeService = ExecuteService(
            clipboardService: ClipboardService(),
            pasteService: PasteService(),
            entryRepository: entryRepository,
            logRepository: logRepository,
            permissionService: permissionService,
            targetApplicationProvider: { nil },
            currentFrontApplicationProvider: { nil }
        )

        let viewModel = QuickPanelViewModel(
            appState: appState,
            projectRepository: projectRepository,
            settingsRepository: settingsRepository,
            searchService: EntrySearchService(entryRepository: entryRepository, appState: appState),
            executeService: executeService,
            permissionService: permissionService,
            panelOpenTracker: PanelOpenTracker(),
            onClosePanel: {}
        )

        viewModel.prepareForPresentation()
        XCTAssertFalse(viewModel.isExecutionReady)

        let expectation = XCTestExpectation(description: "execution unlock")
        viewModel.handleSearchFieldFocus(PanelFocusResult(token: viewModel.focusToken, succeeded: true))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(viewModel.isExecutionReady)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    @MainActor
    func testPanelOpenTrackerRecordsDurations() {
        let tracker = PanelOpenTracker()

        tracker.markHotkeyTriggered()
        tracker.markPanelShown()
        tracker.markSearchFieldFocused(PanelFocusResult(token: 1, succeeded: true))

        let trace = try? XCTUnwrap(tracker.currentTrace)
        XCTAssertNotNil(trace ?? nil)
        XCTAssertNotNil(trace??.hotkeyToPanelShownMs)
        XCTAssertNotNil(trace??.hotkeyToSearchFieldFocusedMs)
    }

    func testPanelVisibilityCoordinatorTransitions() {
        let coordinator = PanelVisibilityCoordinator()

        XCTAssertEqual(coordinator.toggleAction(), .show)
        XCTAssertTrue(coordinator.beginShow())
        coordinator.finishShow()
        XCTAssertEqual(coordinator.state, .visible)
        XCTAssertEqual(coordinator.toggleAction(), .hide)
        XCTAssertTrue(coordinator.beginHide())
        coordinator.finishHide()
        XCTAssertEqual(coordinator.state, .hidden)
    }

    func testDatabaseManagerRecoversFromCorruptedStore() throws {
        let brokenDatabaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        try Data("not a sqlite database".utf8).write(to: brokenDatabaseURL)

        let databaseManager = try DatabaseManager(url: brokenDatabaseURL)
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)

        XCTAssertNotNil(databaseManager.launchRecoveryReport)
        XCTAssertNotNil(try projectRepository.fetchDefault())
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: databaseManager.launchRecoveryReport?.quarantinedFilesDirectoryURL
                    .appendingPathComponent(brokenDatabaseURL.lastPathComponent)
                    .path ?? ""
            )
        )
    }

    func testStorageMaintenanceCreatesBackupAndPrunesOldCopies() throws {
        let databaseManager = try makeDatabaseManager()
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let maintenanceService = StorageMaintenanceService(
            dbQueue: databaseManager.dbQueue,
            logRepository: logRepository,
            databaseURL: databaseManager.databaseURL
        )

        _ = try maintenanceService.createManualBackup()
        _ = try maintenanceService.createManualBackup()
        _ = try maintenanceService.createManualBackup()

        let snapshot = try maintenanceService.healthSnapshot()
        XCTAssertGreaterThanOrEqual(snapshot.backupCount, 1)
        XCTAssertLessThanOrEqual(snapshot.backupCount, Constants.automaticBackupRetentionCount)
        XCTAssertNotNil(snapshot.latestBackupURL)
    }
}

#elseif canImport(Testing)
import Testing

@Test
func constantsExist() {
    #expect(Constants.appName == "PromptPanel")
    #expect(Constants.bundleIdentifier == "com.promptpanel.app")
    #expect(Constants.defaultProjectName == "通用项目")
}

@Test
func databaseSeedsDefaultProjectAndCurrentProject() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)

    let defaultProject = try #require(projectRepository.fetchDefault())
    #expect(defaultProject.name == Constants.defaultProjectName)
    #expect(try settingsRepository.getCurrentProjectId() == defaultProject.id)
}

@Test
func mixedEntriesPreferCurrentProjectWhenSortKeysEqual() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

    let defaultProject = try #require(projectRepository.fetchDefault())
    let currentProject = Project(name: "Current")
    try projectRepository.create(currentProject)

    let now = Date()
    try entryRepository.create(
        Entry(
            projectId: defaultProject.id,
            title: "共享标题",
            content: "通用内容",
            sortOrder: 10,
            useCount: 4,
            lastUsedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )
    try entryRepository.create(
        Entry(
            projectId: currentProject.id,
            title: "共享标题",
            content: "当前内容",
            sortOrder: 10,
            useCount: 4,
            lastUsedAt: now,
            createdAt: now,
            updatedAt: now
        )
    )

    let result = try entryRepository.fetchMixed(
        currentProjectId: currentProject.id,
        defaultProjectId: defaultProject.id
    )

    #expect(result.count == 2)
    #expect(result.first?.projectId == currentProject.id)
    #expect(result.last?.projectId == defaultProject.id)
}

@Test
func migrateAndDeleteMovesEntriesToTargetProject() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

    let sourceProject = Project(name: "Source")
    let targetProject = Project(name: "Target")
    try projectRepository.create(sourceProject)
    try projectRepository.create(targetProject)

    let entry = Entry(projectId: sourceProject.id, title: "Snippet", content: "echo hello")
    try entryRepository.create(entry)

    try projectRepository.migrateAndDelete(fromId: sourceProject.id, toId: targetProject.id)

    #expect(try projectRepository.fetchById(sourceProject.id) == nil)
    let migratedEntry = try #require(entryRepository.fetchById(entry.id))
    #expect(migratedEntry.projectId == targetProject.id)
}

@Test
func executionLogPersistsFailureReasonAndDiagnostics() throws {
    let databaseManager = try makeDatabaseManager()
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)

    let log = ExecutionLog(
        entryId: "entry-1",
        projectId: "project-1",
        frontAppBundleId: "com.apple.Safari",
        observedAppBundleId: Bundle.main.bundleIdentifier,
        hasAccessibility: true,
        clipboardSuccess: true,
        pasteAttempted: false,
        pasteSuccess: false,
        result: Constants.ExecutionResult.clipboardOnly.rawValue,
        failureReason: Constants.ExecutionFailureReason.targetAppNotRestored.rawValue,
        totalDurationMs: 143
    )

    try logRepository.record(log)
    let recentLogs = try logRepository.fetchRecent(limit: 10)
    let persisted = try #require(recentLogs.first)

    #expect(persisted.failureReason == Constants.ExecutionFailureReason.targetAppNotRestored.rawValue)
    #expect(persisted.totalDurationMs == 143)
    #expect(persisted.observedAppBundleId == Bundle.main.bundleIdentifier)
}

@MainActor
@Test
func hotkeyServiceInvokesToggleAndStartsTrace() {
    let registrar = FakeHotkeyRegistrar()
    let tracker = PanelOpenTracker()
    var toggleCount = 0

    let service = HotkeyService(
        onTogglePanel: { toggleCount += 1 },
        registrar: registrar,
        panelOpenTracker: tracker
    )

    service.start()
    registrar.trigger(.togglePanel)

    #expect(toggleCount == 1)
    #expect(tracker.currentTrace != nil)
}

@MainActor
@Test
func quickPanelPrepareForPresentationResetsStateAndRequestsFocus() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
    let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
    let permissionService = PermissionService()
    let appState = AppState()
    let defaultProject = try #require(projectRepository.fetchDefault())
    appState.loadPersistedState(currentProjectId: defaultProject.id, defaultProjectId: defaultProject.id)

    let currentProject = Project(name: "Current")
    try projectRepository.create(currentProject)
    try settingsRepository.setCurrentProjectId(currentProject.id)
    appState.currentProjectId = currentProject.id

    let executeService = ExecuteService(
        clipboardService: ClipboardService(),
        pasteService: PasteService(),
        entryRepository: entryRepository,
        logRepository: logRepository,
        permissionService: permissionService,
        targetApplicationProvider: { nil },
        currentFrontApplicationProvider: { nil }
    )

    let viewModel = QuickPanelViewModel(
        appState: appState,
        projectRepository: projectRepository,
        settingsRepository: settingsRepository,
        searchService: EntrySearchService(entryRepository: entryRepository, appState: appState),
        executeService: executeService,
        permissionService: permissionService,
        panelOpenTracker: PanelOpenTracker(),
        onClosePanel: {}
    )

    viewModel.query = "old-query"
    viewModel.selectedIndex = 4
    let previousFocusToken = viewModel.focusToken

    viewModel.prepareForPresentation()

    #expect(viewModel.query == "")
    #expect(viewModel.selectedIndex == 0)
    #expect(viewModel.currentProjectId == currentProject.id)
    #expect(viewModel.focusToken == previousFocusToken + 1)
    #expect(viewModel.isExecutionReady == false)
    #expect(!viewModel.projectOptions.isEmpty)
}

@MainActor
@Test
func quickPanelExecutionUnlocksAfterFocusResolution() async throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
    let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
    let permissionService = PermissionService()
    let appState = AppState()
    let defaultProject = try #require(projectRepository.fetchDefault())
    appState.loadPersistedState(currentProjectId: defaultProject.id, defaultProjectId: defaultProject.id)

    let executeService = ExecuteService(
        clipboardService: ClipboardService(),
        pasteService: PasteService(),
        entryRepository: entryRepository,
        logRepository: logRepository,
        permissionService: permissionService,
        targetApplicationProvider: { nil },
        currentFrontApplicationProvider: { nil }
    )

    let viewModel = QuickPanelViewModel(
        appState: appState,
        projectRepository: projectRepository,
        settingsRepository: settingsRepository,
        searchService: EntrySearchService(entryRepository: entryRepository, appState: appState),
        executeService: executeService,
        permissionService: permissionService,
        panelOpenTracker: PanelOpenTracker(),
        onClosePanel: {}
    )

    viewModel.prepareForPresentation()
    #expect(viewModel.isExecutionReady == false)

    viewModel.handleSearchFieldFocus(PanelFocusResult(token: viewModel.focusToken, succeeded: true))
    try await Task.sleep(for: .milliseconds(100))

    #expect(viewModel.isExecutionReady == true)
}

@MainActor
@Test
func panelOpenTrackerRecordsDurations() {
    let tracker = PanelOpenTracker()

    tracker.markHotkeyTriggered()
    tracker.markPanelShown()
    tracker.markSearchFieldFocused(PanelFocusResult(token: 1, succeeded: true))

    let trace = tracker.currentTrace
    #expect(trace != nil)
    #expect(trace?.hotkeyToPanelShownMs != nil)
    #expect(trace?.hotkeyToSearchFieldFocusedMs != nil)
}

@Test
func panelVisibilityCoordinatorTransitions() {
    let coordinator = PanelVisibilityCoordinator()

    #expect(coordinator.toggleAction() == .show)
    #expect(coordinator.beginShow())
    coordinator.finishShow()
    #expect(coordinator.state == .visible)
    #expect(coordinator.toggleAction() == .hide)
    #expect(coordinator.beginHide())
    coordinator.finishHide()
    #expect(coordinator.state == .hidden)
}

@Test
func databaseManagerRecoversFromCorruptedStore() throws {
    let brokenDatabaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")

    try Data("not a sqlite database".utf8).write(to: brokenDatabaseURL)

    let databaseManager = try DatabaseManager(url: brokenDatabaseURL)
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)

    #expect(databaseManager.launchRecoveryReport != nil)
    #expect(try projectRepository.fetchDefault() != nil)

    let recoveredFileURL = databaseManager.launchRecoveryReport?.quarantinedFilesDirectoryURL
        .appendingPathComponent(brokenDatabaseURL.lastPathComponent)
    #expect(FileManager.default.fileExists(atPath: recoveredFileURL?.path ?? ""))
}

@Test
func storageMaintenanceCreatesBackupAndPrunesOldCopies() throws {
    let databaseManager = try makeDatabaseManager()
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
    let maintenanceService = StorageMaintenanceService(
        dbQueue: databaseManager.dbQueue,
        logRepository: logRepository,
        databaseURL: databaseManager.databaseURL
    )

    _ = try maintenanceService.createManualBackup()
    _ = try maintenanceService.createManualBackup()
    _ = try maintenanceService.createManualBackup()

    let snapshot = try maintenanceService.healthSnapshot()
    #expect(snapshot.backupCount >= 1)
    #expect(snapshot.backupCount <= Constants.automaticBackupRetentionCount)
    #expect(snapshot.latestBackupURL != nil)
}
#endif

private final class FakeHotkeyRegistrar: HotkeyRegistrationHandling {
    private var handlers: [String: () -> Void] = [:]

    func onKeyUp(for name: KeyboardShortcuts.Name, action: @escaping () -> Void) {
        handlers[name.rawValue] = action
    }

    func disable(_ name: KeyboardShortcuts.Name) {
        handlers.removeValue(forKey: name.rawValue)
    }

    func trigger(_ name: KeyboardShortcuts.Name) {
        handlers[name.rawValue]?()
    }
}

private func makeDatabaseManager() throws -> DatabaseManager {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")
    return try DatabaseManager(url: databaseURL)
}
