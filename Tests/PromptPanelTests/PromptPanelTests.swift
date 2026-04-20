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
        XCTAssertEqual(Constants.panelWindowSize.width, Constants.panelContentSize.width + Constants.panelContentInsets.left + Constants.panelContentInsets.right)
        XCTAssertEqual(Constants.panelWindowSize.height, Constants.panelContentSize.height + Constants.panelContentInsets.top + Constants.panelContentInsets.bottom)
    }

    func testDatabaseSeedsDefaultProjectAndCurrentProject() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)

        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        XCTAssertEqual(defaultProject.name, Constants.defaultProjectName)
        XCTAssertEqual(try settingsRepository.getCurrentProjectId(), defaultProject.id)
    }

    func testResolveCurrentProjectSelectionFallsBackToDefaultWhenPersistedProjectIsDangling() throws {
        let defaultProjectId = UUID().uuidString

        let resolution = try AppDelegate.resolveCurrentProjectSelection(
            persistedCurrentProjectId: "missing-project",
            defaultProjectId: defaultProjectId,
            currentProjectExists: { $0 == defaultProjectId }
        )

        XCTAssertEqual(resolution.projectId, defaultProjectId)
        XCTAssertTrue(resolution.needsPersistence)
        XCTAssertNotNil(resolution.repairReason)
    }

    func testResolveCurrentProjectSelectionKeepsValidPersistedProject() throws {
        let currentProjectId = UUID().uuidString
        let defaultProjectId = UUID().uuidString

        let resolution = try AppDelegate.resolveCurrentProjectSelection(
            persistedCurrentProjectId: currentProjectId,
            defaultProjectId: defaultProjectId,
            currentProjectExists: { $0 == currentProjectId }
        )

        XCTAssertEqual(resolution.projectId, currentProjectId)
        XCTAssertFalse(resolution.needsPersistence)
        XCTAssertNil(resolution.repairReason)
    }

    func testPanelPinnedSettingRoundTrips() throws {
        let databaseManager = try makeDatabaseManager()
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)

        XCTAssertFalse(try settingsRepository.isPanelPinned())

        try settingsRepository.setPanelPinned(true)
        XCTAssertTrue(try settingsRepository.isPanelPinned())

        try settingsRepository.setPanelPinned(false)
        XCTAssertFalse(try settingsRepository.isPanelPinned())
    }

    func testPanelContentSizeSettingRoundTripsWithNormalization() throws {
        let databaseManager = try makeDatabaseManager()
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)

        XCTAssertEqual(try settingsRepository.getPanelContentSize(), Constants.panelContentSize)

        try settingsRepository.setPanelContentSize(NSSize(width: 820, height: 520))
        XCTAssertEqual(try settingsRepository.getPanelContentSize(), NSSize(width: 820, height: 520))

        try settingsRepository.setPanelContentSize(NSSize(width: 2000, height: 100))
        XCTAssertEqual(try settingsRepository.getPanelContentSize(), NSSize(width: Constants.panelMaxContentSize.width, height: Constants.panelMinContentSize.height))
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

    func testDeletingDefaultProjectFails() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())

        XCTAssertThrowsError(try projectRepository.delete(id: defaultProject.id)) { error in
            guard case RepositoryError.cannotDeleteDefault = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testDeletingNonEmptyProjectFailsWithEntryCount() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

        let project = Project(name: "Occupied")
        try projectRepository.create(project)
        try entryRepository.create(Entry(projectId: project.id, title: "Snippet", content: "echo hello"))

        XCTAssertThrowsError(try projectRepository.delete(id: project.id)) { error in
            guard case RepositoryError.projectNotEmpty(let count) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(count, 1)
        }
    }

    func testEntrySearchServiceReturnsDefaultOnlyWhenDefaultProjectIsActive() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let searchService = EntrySearchService(entryRepository: entryRepository)

        try entryRepository.create(Entry(projectId: defaultProject.id, title: "Common", content: "Shared content"))

        let results = try searchService.search(
            query: "",
            currentProjectId: defaultProject.id,
            defaultProjectId: defaultProject.id
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.projectId, defaultProject.id)
    }

    func testEntrySearchServiceReturnsMixedResultsForCurrentAndDefaultProjects() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let currentProject = Project(name: "Current")
        try projectRepository.create(currentProject)
        let searchService = EntrySearchService(entryRepository: entryRepository)

        try entryRepository.create(Entry(projectId: defaultProject.id, title: "Common", content: "Shared content"))
        try entryRepository.create(Entry(projectId: currentProject.id, title: "Current", content: "Current content"))

        let results = try searchService.search(
            query: "",
            currentProjectId: currentProject.id,
            defaultProjectId: defaultProject.id
        )

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(Set(results.map(\.projectId)), Set([defaultProject.id, currentProject.id]))
    }

    func testEntrySearchEscapesQuotedTokens() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let searchService = EntrySearchService(entryRepository: entryRepository)

        try entryRepository.create(
            Entry(
                projectId: defaultProject.id,
                title: #"He said "hello""#,
                content: "Quoted content"
            )
        )

        let results = try searchService.search(
            query: #""hello""#,
            currentProjectId: defaultProject.id,
            defaultProjectId: defaultProject.id
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, #"He said "hello""#)
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
            triggerSource: Constants.ExecutionTrigger.keyboardSubmit.rawValue,
            failureReason: Constants.ExecutionFailureReason.targetAppNotRestored.rawValue,
            targetAppRestoreDurationMs: 86,
            totalDurationMs: 143
        )

        try logRepository.record(log)
        let recentLogs = try logRepository.fetchRecent(limit: 10)
        let persisted = try XCTUnwrap(recentLogs.first)

        XCTAssertEqual(persisted.failureReason, Constants.ExecutionFailureReason.targetAppNotRestored.rawValue)
        XCTAssertEqual(persisted.triggerSource, Constants.ExecutionTrigger.keyboardSubmit.rawValue)
        XCTAssertEqual(persisted.targetAppRestoreDurationMs, 86)
        XCTAssertEqual(persisted.totalDurationMs, 143)
        XCTAssertEqual(persisted.observedAppBundleId, Bundle.main.bundleIdentifier)
    }

    @MainActor
    func testExecuteServiceLogsAccessibilityFallback() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let entry = Entry(projectId: defaultProject.id, title: "Prompt", content: "Copy me")
        try entryRepository.create(entry)
        let pasteDispatcher = FakePasteDispatcher(result: .dispatched)

        let service = ExecuteService(
            clipboardService: FakeClipboardWriter(success: true),
            pasteService: pasteDispatcher,
            entryRepository: entryRepository,
            logRepository: logRepository,
            permissionService: FakePermissionProvider(isAccessibilityGranted: false),
            targetApplicationProvider: { "com.google.Chrome" },
            currentFrontApplicationProvider: { "com.google.Chrome" }
        )

        service.execute(entry: entry, currentProjectId: defaultProject.id, triggerSource: .keyboardSubmit)
        let persisted = try waitForRecentExecutionLog(logRepository)

        XCTAssertEqual(persisted.result, Constants.ExecutionResult.clipboardOnly.rawValue)
        XCTAssertEqual(persisted.failureReason, Constants.ExecutionFailureReason.accessibilityNotGranted.rawValue)
        XCTAssertEqual(persisted.triggerSource, Constants.ExecutionTrigger.keyboardSubmit.rawValue)
        XCTAssertFalse(persisted.pasteAttempted)
        XCTAssertEqual(pasteDispatcher.attemptCount, 0)
    }

    @MainActor
    func testExecuteServiceLogsTargetRestoreMismatchBeforePaste() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let entry = Entry(projectId: defaultProject.id, title: "Prompt", content: "Copy me")
        try entryRepository.create(entry)
        let pasteDispatcher = FakePasteDispatcher(result: .dispatched)

        let service = ExecuteService(
            clipboardService: FakeClipboardWriter(success: true),
            pasteService: pasteDispatcher,
            entryRepository: entryRepository,
            logRepository: logRepository,
            permissionService: FakePermissionProvider(isAccessibilityGranted: true),
            targetApplicationProvider: { "com.google.Chrome" },
            currentFrontApplicationProvider: { "com.apple.finder" }
        )

        service.execute(entry: entry, currentProjectId: defaultProject.id, triggerSource: .keyboardSubmit)
        let persisted = try waitForRecentExecutionLog(logRepository, timeout: 2)

        XCTAssertEqual(persisted.result, Constants.ExecutionResult.clipboardOnly.rawValue)
        XCTAssertEqual(persisted.failureReason, Constants.ExecutionFailureReason.targetAppNotRestored.rawValue)
        XCTAssertEqual(persisted.observedAppBundleId, "com.apple.finder")
        XCTAssertEqual(persisted.triggerSource, Constants.ExecutionTrigger.keyboardSubmit.rawValue)
        XCTAssertNotNil(persisted.targetAppRestoreDurationMs)
        XCTAssertEqual(pasteDispatcher.attemptCount, 0)
    }

    @MainActor
    func testExecuteServiceLogsPasteEventCreationFallback() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let entry = Entry(projectId: defaultProject.id, title: "Prompt", content: "Copy me")
        try entryRepository.create(entry)
        let pasteDispatcher = FakePasteDispatcher(result: .eventCreationFailed)

        let service = ExecuteService(
            clipboardService: FakeClipboardWriter(success: true),
            pasteService: pasteDispatcher,
            entryRepository: entryRepository,
            logRepository: logRepository,
            permissionService: FakePermissionProvider(isAccessibilityGranted: true),
            targetApplicationProvider: { "com.google.Chrome" },
            currentFrontApplicationProvider: { "com.google.Chrome" }
        )

        service.execute(entry: entry, currentProjectId: defaultProject.id, triggerSource: .pointerClick)
        let persisted = try waitForRecentExecutionLog(logRepository)

        XCTAssertEqual(persisted.result, Constants.ExecutionResult.clipboardOnly.rawValue)
        XCTAssertEqual(persisted.failureReason, Constants.ExecutionFailureReason.pasteEventCreationFailed.rawValue)
        XCTAssertEqual(persisted.triggerSource, Constants.ExecutionTrigger.pointerClick.rawValue)
        XCTAssertTrue(persisted.pasteAttempted)
        XCTAssertFalse(persisted.pasteSuccess)
        XCTAssertEqual(pasteDispatcher.attemptCount, 1)
    }

    @MainActor
    func testExecuteServiceIgnoresConcurrentDuplicateExecutionRequests() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        let entry = Entry(projectId: defaultProject.id, title: "Prompt", content: "Copy me")
        try entryRepository.create(entry)
        let pasteDispatcher = FakePasteDispatcher(result: .dispatched)

        let service = ExecuteService(
            clipboardService: FakeClipboardWriter(success: true),
            pasteService: pasteDispatcher,
            entryRepository: entryRepository,
            logRepository: logRepository,
            permissionService: FakePermissionProvider(isAccessibilityGranted: true),
            targetApplicationProvider: { "com.google.Chrome" },
            currentFrontApplicationProvider: { "com.google.Chrome" }
        )

        service.execute(entry: entry, currentProjectId: defaultProject.id, triggerSource: .keyboardSubmit)
        service.execute(entry: entry, currentProjectId: defaultProject.id, triggerSource: .pointerClick)

        _ = try waitForRecentExecutionLog(logRepository)
        let recentLogs = try logRepository.fetchRecent(limit: 10)
        let persistedEntry = try XCTUnwrap(try entryRepository.fetch(id: entry.id))

        XCTAssertEqual(recentLogs.count, 1)
        XCTAssertEqual(recentLogs.first?.triggerSource, Constants.ExecutionTrigger.keyboardSubmit.rawValue)
        XCTAssertEqual(pasteDispatcher.attemptCount, 1)
        XCTAssertEqual(persistedEntry.useCount, 1)
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
    func testHotkeyServiceMigratesLegacyDefaultShortcut() {
        let registrar = FakeHotkeyRegistrar()
        let migrationDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let legacyShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option])
        let originalShortcut = KeyboardShortcuts.Name.togglePanel.shortcut
        defer {
            KeyboardShortcuts.setShortcut(originalShortcut, for: .togglePanel)
        }

        KeyboardShortcuts.setShortcut(legacyShortcut, for: .togglePanel)
        migrationDefaults.removeObject(forKey: "toggle_panel_shortcut_migrated_to_option_2")

        let service = HotkeyService(
            onTogglePanel: {},
            registrar: registrar,
            panelOpenTracker: nil,
            userDefaults: migrationDefaults
        )

        service.start()

        XCTAssertEqual(KeyboardShortcuts.Name.togglePanel.shortcut, KeyboardShortcuts.Shortcut(.two, modifiers: [.option]))
        XCTAssertTrue(migrationDefaults.bool(forKey: "toggle_panel_shortcut_migrated_to_option_2"))
    }

    @MainActor
    func testHotkeyServiceMigratesPreviousPreferredShortcutToNewDefault() {
        let registrar = FakeHotkeyRegistrar()
        let migrationDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let previousPreferredShortcut = KeyboardShortcuts.Shortcut(.p, modifiers: [.option, .shift])
        let originalShortcut = KeyboardShortcuts.Name.togglePanel.shortcut
        defer {
            KeyboardShortcuts.setShortcut(originalShortcut, for: .togglePanel)
        }

        KeyboardShortcuts.setShortcut(previousPreferredShortcut, for: .togglePanel)
        migrationDefaults.removeObject(forKey: "toggle_panel_shortcut_migrated_to_option_2")

        let service = HotkeyService(
            onTogglePanel: {},
            registrar: registrar,
            panelOpenTracker: nil,
            userDefaults: migrationDefaults
        )

        service.start()

        XCTAssertEqual(KeyboardShortcuts.Name.togglePanel.shortcut, KeyboardShortcuts.Shortcut(.two, modifiers: [.option]))
        XCTAssertTrue(migrationDefaults.bool(forKey: "toggle_panel_shortcut_migrated_to_option_2"))
    }

    func testAppLaunchCoordinatorReturnsNilWhenOnlyCurrentProcessExists() {
        XCTAssertNil(
            AppLaunchCoordinator.duplicateProcessIdentifier(
                currentProcessIdentifier: 42,
                runningProcessIdentifiers: [42]
            )
        )
    }

    func testAppLaunchCoordinatorReturnsExistingProcessWhenDuplicateExists() {
        XCTAssertEqual(
            AppLaunchCoordinator.duplicateProcessIdentifier(
                currentProcessIdentifier: 42,
                runningProcessIdentifiers: [42, 7, 7]
            ),
            7
        )
    }

    func testAppLaunchCoordinatorSkipsDuplicateCheckWhenOverrideIsEnabled() {
        XCTAssertTrue(
            AppLaunchCoordinator.shouldSkipDuplicateCheck(
                environment: [AppLaunchCoordinator.allowExistingInstanceEnvironmentKey: "1"]
            )
        )
        XCTAssertFalse(AppLaunchCoordinator.shouldSkipDuplicateCheck(environment: [:]))
    }

    func testAppLaunchCoordinatorReturnsNilWhenDuplicateExitsDuringSettleWindow() {
        var samples = [
            [pid_t(42), pid_t(7)],
            [pid_t(42)]
        ]

        let result = AppLaunchCoordinator.duplicateProcessIdentifierAfterSettling(
            currentProcessIdentifier: 42,
            timeoutMs: 20,
            pollIntervalMs: 1,
            runningProcessIdentifiersProvider: {
                let next = samples.first ?? [pid_t(42)]
                if samples.isEmpty == false {
                    samples.removeFirst()
                }
                return next
            },
            sleep: { _ in }
        )

        XCTAssertNil(result)
    }

    func testAppLaunchCoordinatorReturnsDuplicateWhenItPersistsPastSettleWindow() {
        let result = AppLaunchCoordinator.duplicateProcessIdentifierAfterSettling(
            currentProcessIdentifier: 42,
            timeoutMs: 0,
            pollIntervalMs: 1,
            runningProcessIdentifiersProvider: { [42, 7] },
            sleep: { _ in }
        )

        XCTAssertEqual(result, 7)
    }

    func testPanelActivationPolicyPromotesAppWhenAnyWindowIsVisible() {
        XCTAssertEqual(
            PanelService.desiredActivationPolicy(isPanelVisible: true, isMainWindowVisible: false),
            .regular
        )
        XCTAssertEqual(
            PanelService.desiredActivationPolicy(isPanelVisible: false, isMainWindowVisible: true),
            .regular
        )
        XCTAssertEqual(
            PanelService.desiredActivationPolicy(isPanelVisible: false, isMainWindowVisible: false),
            .accessory
        )
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
            searchService: EntrySearchService(entryRepository: entryRepository),
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
        XCTAssertFalse(viewModel.projects.isEmpty)
    }

    @MainActor
    func testMainWindowCurrentProjectUpdatesAfterSelectingNewCurrentProject() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let permissionService = PermissionService()
        let loginItemService = LoginItemService()
        let updaterService = UpdaterService()
        let storageMaintenanceService = StorageMaintenanceService(
            dbQueue: databaseManager.dbQueue,
            logRepository: logRepository,
            databaseURL: databaseManager.databaseURL
        )
        let appState = AppState()
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        appState.loadPersistedState(currentProjectId: defaultProject.id, defaultProjectId: defaultProject.id)

        let currentProject = Project(name: "Current")
        try projectRepository.create(currentProject)

        let viewModel = MainWindowViewModel(
            appState: appState,
            projectRepository: projectRepository,
            entryRepository: entryRepository,
            settingsRepository: settingsRepository,
            logRepository: logRepository,
            permissionService: permissionService,
            loginItemService: loginItemService,
            storageMaintenanceService: storageMaintenanceService,
            updaterService: updaterService,
            launchRecoveryReport: nil
        )

        viewModel.load()
        viewModel.selectedProjectId = currentProject.id
        viewModel.setCurrentProjectToSelected()

        XCTAssertEqual(viewModel.currentProjectId, currentProject.id)
        XCTAssertEqual(appState.currentProjectId, currentProject.id)
        XCTAssertEqual(try settingsRepository.getCurrentProjectId(), currentProject.id)
        XCTAssertEqual(viewModel.bannerMessage, "当前项目已切换为 \(currentProject.name)。")
    }

    @MainActor
    func testQuickPanelClearsResultsWhileAsyncSearchIsPending() throws {
        let databaseManager = try makeDatabaseManager()
        let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let permissionService = PermissionService()
        let appState = AppState()
        let defaultProject = try XCTUnwrap(projectRepository.fetchDefault())
        appState.loadPersistedState(currentProjectId: defaultProject.id, defaultProjectId: defaultProject.id)

        try entryRepository.create(Entry(projectId: defaultProject.id, title: "Alpha", content: "Alpha body"))
        try entryRepository.create(Entry(projectId: defaultProject.id, title: "Beta", content: "Beta body"))

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
            searchService: EntrySearchService(entryRepository: entryRepository),
            executeService: executeService,
            permissionService: permissionService,
            panelOpenTracker: PanelOpenTracker(),
            onClosePanel: {}
        )

        viewModel.prepareForPresentation()
        let loadDeadline = Date().addingTimeInterval(1)
        while viewModel.entries.count != 2 && Date() < loadDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertEqual(viewModel.entries.count, 2)

        viewModel.query = "Alpha"

        XCTAssertTrue(viewModel.entries.isEmpty)
        XCTAssertNil(viewModel.selectedEntry)
    }

    @MainActor
    func testQuickPanelDoesNotUnlockExecutionWhenSearchFieldFocusFails() throws {
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
            searchService: EntrySearchService(entryRepository: entryRepository),
            executeService: executeService,
            permissionService: permissionService,
            panelOpenTracker: PanelOpenTracker(),
            onClosePanel: {}
        )

        viewModel.prepareForPresentation()
        viewModel.handleSearchFieldFocus(PanelFocusResult(token: viewModel.focusToken, succeeded: false))

        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        XCTAssertFalse(viewModel.isExecutionReady)
    }

    @MainActor
    func testQuickPanelExecutionUnlocksAfterManualFocusRecovery() throws {
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
            searchService: EntrySearchService(entryRepository: entryRepository),
            executeService: executeService,
            permissionService: permissionService,
            panelOpenTracker: PanelOpenTracker(),
            onClosePanel: {}
        )

        viewModel.prepareForPresentation()
        let focusToken = viewModel.focusToken
        viewModel.handleSearchFieldFocus(PanelFocusResult(token: focusToken, succeeded: false))
        viewModel.handleSearchFieldFocus(
            PanelFocusResult(token: focusToken, succeeded: true, attempt: Constants.panelFocusMaxAttempts)
        )

        RunLoop.main.run(until: Date().addingTimeInterval(0.12))

        XCTAssertTrue(viewModel.isExecutionReady)
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
            searchService: EntrySearchService(entryRepository: entryRepository),
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

    func testTargetApplicationRestoreMismatchRequiresConfirmedDifferentBundleId() {
        XCTAssertFalse(
            ExecuteService.isTargetApplicationRestoreMismatch(
                expectedBundleId: "com.example.target",
                observedBundleId: nil
            )
        )
        XCTAssertFalse(
            ExecuteService.isTargetApplicationRestoreMismatch(
                expectedBundleId: nil,
                observedBundleId: "com.example.target"
            )
        )
        XCTAssertTrue(
            ExecuteService.isTargetApplicationRestoreMismatch(
                expectedBundleId: "com.example.target",
                observedBundleId: "com.example.other"
            )
        )
    }

    @MainActor
    func testQuickPanelRetryFocusAfterActivationStabilizedRequestsAnotherFocusCycle() throws {
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
            searchService: EntrySearchService(entryRepository: entryRepository),
            executeService: executeService,
            permissionService: permissionService,
            panelOpenTracker: PanelOpenTracker(),
            onClosePanel: {}
        )

        viewModel.prepareForPresentation()
        let initialFocusToken = viewModel.focusToken
        viewModel.handleSearchFieldFocus(PanelFocusResult(token: initialFocusToken, succeeded: true))
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        XCTAssertTrue(viewModel.isExecutionReady)

        viewModel.retryFocusAfterActivationStabilized()

        XCTAssertEqual(viewModel.focusToken, initialFocusToken + 1)
        XCTAssertFalse(viewModel.isExecutionReady)
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

    func testPanelActivationActionRetriesUntilMaxAttempts() {
        let unstableSnapshot = PanelActivationSnapshot(
            appIsActive: false,
            panelIsVisible: true,
            panelIsKey: false
        )
        let stableSnapshot = PanelActivationSnapshot(
            appIsActive: true,
            panelIsVisible: true,
            panelIsKey: true
        )

        XCTAssertEqual(
            PanelService.activationAction(snapshot: unstableSnapshot, attempt: 0, maxAttempts: 3),
            .retry(nextAttempt: 1)
        )
        XCTAssertEqual(
            PanelService.activationAction(snapshot: unstableSnapshot, attempt: 3, maxAttempts: 3),
            .failed
        )
        XCTAssertEqual(
            PanelService.activationAction(snapshot: stableSnapshot, attempt: 1, maxAttempts: 3),
            .stable
        )
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

    func testQuickPanelWindowCanBecomeKeyAndMain() {
        let panel = QuickPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.canBecomeMain)
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

    func testDatabaseManagerDoesNotQuarantineStoreWhenMigrationFails() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let queue = try DatabaseQueue(path: databaseURL.path)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE execution_logs (
                    id TEXT PRIMARY KEY NOT NULL,
                    entry_id TEXT NOT NULL,
                    project_id TEXT NOT NULL,
                    front_app_bundle_id TEXT,
                    observed_app_bundle_id TEXT,
                    has_accessibility INTEGER NOT NULL,
                    clipboard_success INTEGER NOT NULL,
                    paste_attempted INTEGER NOT NULL,
                    paste_success INTEGER NOT NULL,
                    result TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
                """)
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT PRIMARY KEY NOT NULL)")
            try db.execute(sql: "INSERT INTO grdb_migrations(identifier) VALUES (?)", arguments: ["v1_create_tables"])
        }

        XCTAssertThrowsError(try DatabaseManager(url: databaseURL)) { error in
            guard case DatabaseManager.InitializationError.migrationFailedPreservingStore = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Constants.recoveryDirectory(for: databaseURL).path))
    }

    func testStorageMaintenanceKeepsManualBackupsBeyondAutomaticRetention() throws {
        let databaseManager = try makeDatabaseManager()
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let maintenanceService = StorageMaintenanceService(
            dbQueue: databaseManager.dbQueue,
            logRepository: logRepository,
            databaseURL: databaseManager.databaseURL
        )

        let backupTarget = Constants.automaticBackupRetentionCount + 2
        for _ in 0..<backupTarget {
            _ = try maintenanceService.createManualBackup()
        }

        let snapshot = try maintenanceService.healthSnapshot()
        XCTAssertEqual(snapshot.backupCount, backupTarget)
        XCTAssertNotNil(snapshot.latestBackupURL)
    }

    func testLaunchMaintenanceDoesNotCreateExtraBackupAfterRecentManualBackup() throws {
        let databaseManager = try makeDatabaseManager()
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let maintenanceService = StorageMaintenanceService(
            dbQueue: databaseManager.dbQueue,
            logRepository: logRepository,
            databaseURL: databaseManager.databaseURL
        )

        let manualBackupURL = try maintenanceService.createManualBackup()
        let beforeSnapshot = try maintenanceService.healthSnapshot()

        _ = try maintenanceService.performLaunchMaintenance()

        let afterSnapshot = try maintenanceService.healthSnapshot()
        XCTAssertEqual(afterSnapshot.backupCount, beforeSnapshot.backupCount)
        XCTAssertEqual(afterSnapshot.latestBackupURL?.lastPathComponent, manualBackupURL.lastPathComponent)
    }

    func testFreshDatabaseDoesNotCreateUnusedTagsIndex() throws {
        let databaseManager = try makeDatabaseManager()
        let indexNames = try databaseManager.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA index_list('entries')")
                .compactMap { row in row["name"] as String? }
        }

        XCTAssertFalse(indexNames.contains("index_entries_on_tags"))
    }

    func testMigrationsDropLegacyTagsIndex() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let queue = try DatabaseQueue(path: databaseURL.path)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE entries (
                    id TEXT PRIMARY KEY NOT NULL,
                    project_id TEXT NOT NULL,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    type TEXT NOT NULL,
                    is_pinned INTEGER NOT NULL,
                    sort_order INTEGER NOT NULL,
                    use_count INTEGER NOT NULL,
                    last_used_at TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    tags TEXT NOT NULL DEFAULT '[]'
                )
                """)
            try db.execute(sql: "CREATE INDEX index_entries_on_tags ON entries(tags)")
            try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT PRIMARY KEY NOT NULL)")
            for identifier in [
                "v1_create_tables",
                "v2_execution_log_diagnostics",
                "v3_execution_log_interaction_diagnostics",
                "v4_entry_tags"
            ] {
                try db.execute(
                    sql: "INSERT INTO grdb_migrations(identifier) VALUES (?)",
                    arguments: [identifier]
                )
            }
        }

        let databaseManager = try DatabaseManager(url: databaseURL)
        let indexNames = try databaseManager.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA index_list('entries')")
                .compactMap { row in row["name"] as String? }
        }

        XCTAssertFalse(indexNames.contains("index_entries_on_tags"))
    }

    func testLogCleanupRemovesOnlyExpiredEntries() throws {
        let databaseManager = try makeDatabaseManager()
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)

        try logRepository.record(
            ExecutionLog(
                entryId: "recent",
                projectId: "project-1",
                hasAccessibility: true,
                clipboardSuccess: true,
                pasteAttempted: true,
                pasteSuccess: true,
                result: Constants.ExecutionResult.success.rawValue,
                createdAt: Date()
            )
        )
        try logRepository.record(
            ExecutionLog(
                entryId: "expired",
                projectId: "project-1",
                hasAccessibility: true,
                clipboardSuccess: true,
                pasteAttempted: false,
                pasteSuccess: false,
                result: Constants.ExecutionResult.clipboardOnly.rawValue,
                createdAt: Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? .distantPast
            )
        )

        try logRepository.cleanup(olderThanDays: 30)
        let remaining = try logRepository.fetchRecent(limit: 10)

        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.entryId, "recent")
    }

    func testHealthSummaryCountsResultsAcrossOutcomes() throws {
        let databaseManager = try makeDatabaseManager()
        let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
        let now = Date()

        try logRepository.record(
            ExecutionLog(
                entryId: "success",
                projectId: "project-1",
                hasAccessibility: true,
                clipboardSuccess: true,
                pasteAttempted: true,
                pasteSuccess: true,
                result: Constants.ExecutionResult.success.rawValue,
                createdAt: now
            )
        )
        try logRepository.record(
            ExecutionLog(
                entryId: "clipboard-only",
                projectId: "project-1",
                hasAccessibility: false,
                clipboardSuccess: true,
                pasteAttempted: false,
                pasteSuccess: false,
                result: Constants.ExecutionResult.clipboardOnly.rawValue,
                createdAt: now
            )
        )
        try logRepository.record(
            ExecutionLog(
                entryId: "failed",
                projectId: "project-1",
                hasAccessibility: true,
                clipboardSuccess: false,
                pasteAttempted: false,
                pasteSuccess: false,
                result: Constants.ExecutionResult.failed.rawValue,
                createdAt: now
            )
        )

        let summary = try logRepository.fetchHealthSummary(
            since: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast
        )

        XCTAssertEqual(summary.totalCount, 3)
        XCTAssertEqual(summary.successCount, 1)
        XCTAssertEqual(summary.clipboardOnlyCount, 1)
        XCTAssertEqual(summary.failedCount, 1)
        XCTAssertNotNil(summary.latestExecutionAt)
        XCTAssertNotNil(summary.latestFailureAt)
    }

    private func waitForRecentExecutionLog(
        _ logRepository: LogRepository,
        timeout: TimeInterval = 1
    ) throws -> ExecutionLog {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let log = try logRepository.fetchRecent(limit: 1).first {
                return log
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        throw NSError(domain: "PromptPanelTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Timed out waiting for execution log"
        ])
    }
}

#elseif canImport(Testing)
import Testing

@Test
func constantsExist() {
    #expect(Constants.appName == "PromptPanel")
    #expect(Constants.bundleIdentifier == "com.promptpanel.app")
    #expect(Constants.defaultProjectName == "通用项目")
    #expect(Constants.panelWindowSize.width == Constants.panelContentSize.width + Constants.panelContentInsets.left + Constants.panelContentInsets.right)
    #expect(Constants.panelWindowSize.height == Constants.panelContentSize.height + Constants.panelContentInsets.top + Constants.panelContentInsets.bottom)
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
func resolveCurrentProjectSelectionFallsBackToDefaultWhenPersistedProjectIsDangling() throws {
    let defaultProjectId = UUID().uuidString

    let resolution = try AppDelegate.resolveCurrentProjectSelection(
        persistedCurrentProjectId: "missing-project",
        defaultProjectId: defaultProjectId,
        currentProjectExists: { $0 == defaultProjectId }
    )

    #expect(resolution.projectId == defaultProjectId)
    #expect(resolution.needsPersistence)
    #expect(resolution.repairReason != nil)
}

@Test
func resolveCurrentProjectSelectionKeepsValidPersistedProject() throws {
    let currentProjectId = UUID().uuidString
    let defaultProjectId = UUID().uuidString

    let resolution = try AppDelegate.resolveCurrentProjectSelection(
        persistedCurrentProjectId: currentProjectId,
        defaultProjectId: defaultProjectId,
        currentProjectExists: { $0 == currentProjectId }
    )

    #expect(resolution.projectId == currentProjectId)
    #expect(!resolution.needsPersistence)
    #expect(resolution.repairReason == nil)
}

@Test
func panelContentSizeSettingRoundTripsWithNormalization() throws {
    let databaseManager = try makeDatabaseManager()
    let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)

    #expect(try settingsRepository.getPanelContentSize() == Constants.panelContentSize)

    try settingsRepository.setPanelContentSize(NSSize(width: 820, height: 520))
    #expect(try settingsRepository.getPanelContentSize() == NSSize(width: 820, height: 520))

    try settingsRepository.setPanelContentSize(NSSize(width: 2000, height: 100))
    #expect(try settingsRepository.getPanelContentSize() == NSSize(width: Constants.panelMaxContentSize.width, height: Constants.panelMinContentSize.height))
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
func deletingDefaultProjectFails() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let defaultProject = try #require(projectRepository.fetchDefault())

    do {
        try projectRepository.delete(id: defaultProject.id)
        Issue.record("Expected deleting the default project to fail.")
    } catch {
        guard case RepositoryError.cannotDeleteDefault = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
    }
}

@Test
func deletingNonEmptyProjectFailsWithEntryCount() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)

    let project = Project(name: "Occupied")
    try projectRepository.create(project)
    try entryRepository.create(Entry(projectId: project.id, title: "Snippet", content: "echo hello"))

    do {
        try projectRepository.delete(id: project.id)
        Issue.record("Expected deleting a non-empty project to fail.")
    } catch {
        guard case RepositoryError.projectNotEmpty(let count) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
        #expect(count == 1)
    }
}

@Test
func entrySearchServiceReturnsDefaultOnlyWhenDefaultProjectIsActive() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
    let defaultProject = try #require(projectRepository.fetchDefault())
    let searchService = EntrySearchService(entryRepository: entryRepository)

    try entryRepository.create(Entry(projectId: defaultProject.id, title: "Common", content: "Shared content"))

    let results = try searchService.search(
        query: "",
        currentProjectId: defaultProject.id,
        defaultProjectId: defaultProject.id
    )

    #expect(results.count == 1)
    #expect(results.first?.projectId == defaultProject.id)
}

@Test
func entrySearchServiceReturnsMixedResultsForCurrentAndDefaultProjects() throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
    let defaultProject = try #require(projectRepository.fetchDefault())
    let currentProject = Project(name: "Current")
    try projectRepository.create(currentProject)
    let searchService = EntrySearchService(entryRepository: entryRepository)

    try entryRepository.create(Entry(projectId: defaultProject.id, title: "Common", content: "Shared content"))
    try entryRepository.create(Entry(projectId: currentProject.id, title: "Current", content: "Current content"))

    let results = try searchService.search(
        query: "",
        currentProjectId: currentProject.id,
        defaultProjectId: defaultProject.id
    )

    #expect(results.count == 2)
    #expect(Set(results.map(\.projectId)) == Set([defaultProject.id, currentProject.id]))
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
func hotkeyServiceMigratesLegacyDefaultShortcut() {
    let registrar = FakeHotkeyRegistrar()
    let migrationDefaults = UserDefaults(suiteName: UUID().uuidString)!
    let legacyShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option])
    let originalShortcut = KeyboardShortcuts.Name.togglePanel.shortcut
    defer {
        KeyboardShortcuts.setShortcut(originalShortcut, for: .togglePanel)
    }

    KeyboardShortcuts.setShortcut(legacyShortcut, for: .togglePanel)
    migrationDefaults.removeObject(forKey: "toggle_panel_shortcut_migrated_to_option_2")

    let service = HotkeyService(
        onTogglePanel: {},
        registrar: registrar,
        panelOpenTracker: nil,
        userDefaults: migrationDefaults
    )

    service.start()

    #expect(KeyboardShortcuts.Name.togglePanel.shortcut == KeyboardShortcuts.Shortcut(.two, modifiers: [.option]))
    #expect(migrationDefaults.bool(forKey: "toggle_panel_shortcut_migrated_to_option_2"))
}

@MainActor
@Test
func hotkeyServiceMigratesPreviousPreferredShortcutToNewDefault() {
    let registrar = FakeHotkeyRegistrar()
    let migrationDefaults = UserDefaults(suiteName: UUID().uuidString)!
    let previousPreferredShortcut = KeyboardShortcuts.Shortcut(.p, modifiers: [.option, .shift])
    let originalShortcut = KeyboardShortcuts.Name.togglePanel.shortcut
    defer {
        KeyboardShortcuts.setShortcut(originalShortcut, for: .togglePanel)
    }

    KeyboardShortcuts.setShortcut(previousPreferredShortcut, for: .togglePanel)
    migrationDefaults.removeObject(forKey: "toggle_panel_shortcut_migrated_to_option_2")

    let service = HotkeyService(
        onTogglePanel: {},
        registrar: registrar,
        panelOpenTracker: nil,
        userDefaults: migrationDefaults
    )

    service.start()

    #expect(KeyboardShortcuts.Name.togglePanel.shortcut == KeyboardShortcuts.Shortcut(.two, modifiers: [.option]))
    #expect(migrationDefaults.bool(forKey: "toggle_panel_shortcut_migrated_to_option_2"))
}

@Test
func appLaunchCoordinatorReturnsNilWhenOnlyCurrentProcessExists() {
    #expect(
        AppLaunchCoordinator.duplicateProcessIdentifier(
            currentProcessIdentifier: 42,
            runningProcessIdentifiers: [42]
        ) == nil
    )
}

@Test
func appLaunchCoordinatorReturnsExistingProcessWhenDuplicateExists() {
    #expect(
        AppLaunchCoordinator.duplicateProcessIdentifier(
            currentProcessIdentifier: 42,
            runningProcessIdentifiers: [42, 7, 7]
        ) == 7
    )
}

@Test
func appLaunchCoordinatorSkipsDuplicateCheckWhenOverrideIsEnabled() {
    #expect(
        AppLaunchCoordinator.shouldSkipDuplicateCheck(
            environment: [AppLaunchCoordinator.allowExistingInstanceEnvironmentKey: "1"]
        )
    )
    #expect(!AppLaunchCoordinator.shouldSkipDuplicateCheck(environment: [:]))
}

@Test
func appLaunchCoordinatorReturnsNilWhenDuplicateExitsDuringSettleWindow() {
    var samples = [
        [pid_t(42), pid_t(7)],
        [pid_t(42)]
    ]

    let result = AppLaunchCoordinator.duplicateProcessIdentifierAfterSettling(
        currentProcessIdentifier: 42,
        timeoutMs: 20,
        pollIntervalMs: 1,
        runningProcessIdentifiersProvider: {
            let next = samples.first ?? [pid_t(42)]
            if !samples.isEmpty {
                samples.removeFirst()
            }
            return next
        },
        sleep: { _ in }
    )

    #expect(result == nil)
}

@Test
func appLaunchCoordinatorReturnsDuplicateWhenItPersistsPastSettleWindow() {
    let result = AppLaunchCoordinator.duplicateProcessIdentifierAfterSettling(
        currentProcessIdentifier: 42,
        timeoutMs: 0,
        pollIntervalMs: 1,
        runningProcessIdentifiersProvider: { [42, 7] },
        sleep: { _ in }
    )

    #expect(result == 7)
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
        searchService: EntrySearchService(entryRepository: entryRepository),
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
    #expect(!viewModel.projects.isEmpty)
}

@MainActor
@Test
func quickPanelClearsResultsWhileAsyncSearchIsPending() async throws {
    let databaseManager = try makeDatabaseManager()
    let projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
    let entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
    let settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
    let permissionService = PermissionService()
    let appState = AppState()
    let defaultProject = try #require(projectRepository.fetchDefault())
    appState.loadPersistedState(currentProjectId: defaultProject.id, defaultProjectId: defaultProject.id)

    try entryRepository.create(Entry(projectId: defaultProject.id, title: "Alpha", content: "Alpha body"))
    try entryRepository.create(Entry(projectId: defaultProject.id, title: "Beta", content: "Beta body"))

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
        searchService: EntrySearchService(entryRepository: entryRepository),
        executeService: executeService,
        permissionService: permissionService,
        panelOpenTracker: PanelOpenTracker(),
        onClosePanel: {}
    )

    viewModel.prepareForPresentation()

    let clock = ContinuousClock()
    let deadline = clock.now + .seconds(1)
    while viewModel.entries.count != 2 && clock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }

    #expect(viewModel.entries.count == 2)

    viewModel.query = "Alpha"

    #expect(viewModel.entries.isEmpty)
    #expect(viewModel.selectedEntry == nil)
}

@MainActor
@Test
func quickPanelDoesNotUnlockExecutionWhenSearchFieldFocusFails() async throws {
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
        searchService: EntrySearchService(entryRepository: entryRepository),
        executeService: executeService,
        permissionService: permissionService,
        panelOpenTracker: PanelOpenTracker(),
        onClosePanel: {}
    )

    viewModel.prepareForPresentation()
    viewModel.handleSearchFieldFocus(PanelFocusResult(token: viewModel.focusToken, succeeded: false))
    try await Task.sleep(for: .milliseconds(100))

    #expect(viewModel.isExecutionReady == false)
}

@MainActor
@Test
func quickPanelExecutionUnlocksAfterManualFocusRecovery() async throws {
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
        searchService: EntrySearchService(entryRepository: entryRepository),
        executeService: executeService,
        permissionService: permissionService,
        panelOpenTracker: PanelOpenTracker(),
        onClosePanel: {}
    )

    viewModel.prepareForPresentation()
    let focusToken = viewModel.focusToken
    viewModel.handleSearchFieldFocus(PanelFocusResult(token: focusToken, succeeded: false))
    viewModel.handleSearchFieldFocus(
        PanelFocusResult(token: focusToken, succeeded: true, attempt: Constants.panelFocusMaxAttempts)
    )
    try await Task.sleep(for: .milliseconds(120))

    #expect(viewModel.isExecutionReady == true)
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
        searchService: EntrySearchService(entryRepository: entryRepository),
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

@Test
func targetApplicationRestoreMismatchRequiresConfirmedDifferentBundleId() {
    #expect(
        ExecuteService.isTargetApplicationRestoreMismatch(
            expectedBundleId: "com.example.target",
            observedBundleId: nil
        ) == false
    )
    #expect(
        ExecuteService.isTargetApplicationRestoreMismatch(
            expectedBundleId: nil,
            observedBundleId: "com.example.target"
        ) == false
    )
    #expect(
        ExecuteService.isTargetApplicationRestoreMismatch(
            expectedBundleId: "com.example.target",
            observedBundleId: "com.example.other"
        ) == true
    )
}

@MainActor
@Test
func quickPanelRetryFocusAfterActivationStabilizedRequestsAnotherFocusCycle() async throws {
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
        searchService: EntrySearchService(entryRepository: entryRepository),
        executeService: executeService,
        permissionService: permissionService,
        panelOpenTracker: PanelOpenTracker(),
        onClosePanel: {}
    )

    viewModel.prepareForPresentation()
    let initialFocusToken = viewModel.focusToken
    viewModel.handleSearchFieldFocus(PanelFocusResult(token: initialFocusToken, succeeded: true))
    try await Task.sleep(for: .milliseconds(120))
    #expect(viewModel.isExecutionReady == true)

    viewModel.retryFocusAfterActivationStabilized()

    #expect(viewModel.focusToken == initialFocusToken + 1)
    #expect(viewModel.isExecutionReady == false)
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
func panelActivationActionRetriesUntilMaxAttempts() {
    let unstableSnapshot = PanelActivationSnapshot(
        appIsActive: false,
        panelIsVisible: true,
        panelIsKey: false
    )
    let stableSnapshot = PanelActivationSnapshot(
        appIsActive: true,
        panelIsVisible: true,
        panelIsKey: true
    )

    #expect(
        PanelService.activationAction(snapshot: unstableSnapshot, attempt: 0, maxAttempts: 3)
            == .retry(nextAttempt: 1)
    )
    #expect(
        PanelService.activationAction(snapshot: unstableSnapshot, attempt: 3, maxAttempts: 3)
            == .failed
    )
    #expect(
        PanelService.activationAction(snapshot: stableSnapshot, attempt: 1, maxAttempts: 3)
            == .stable
    )
}

@Test
func panelFocusRequiresActiveKeyWindowBeforeUnlockingExecution() {
    #expect(
        PanelFocusResult.interactionReady(
            appIsActive: true,
            windowIsVisible: true,
            windowIsKey: true,
            firstResponderMatches: true,
            hasEditor: false
        )
    )
    #expect(
        !PanelFocusResult.interactionReady(
            appIsActive: false,
            windowIsVisible: true,
            windowIsKey: true,
            firstResponderMatches: true,
            hasEditor: true
        )
    )
    #expect(
        !PanelFocusResult.interactionReady(
            appIsActive: true,
            windowIsVisible: true,
            windowIsKey: false,
            firstResponderMatches: true,
            hasEditor: true
        )
    )
}

@Test
func activationPolicyIsRegularWhenPanelIsVisible() {
    #expect(
        PanelService.desiredActivationPolicy(
            isPanelVisible: true,
            isMainWindowVisible: false
        ) == .regular
    )
}

@Test
func activationPolicyFallsBackToAccessoryOnlyWhenNoForegroundWindowIsVisible() {
    #expect(
        PanelService.desiredActivationPolicy(
            isPanelVisible: false,
            isMainWindowVisible: true
        ) == .regular
    )
    #expect(
        PanelService.desiredActivationPolicy(
            isPanelVisible: false,
            isMainWindowVisible: false
        ) == .accessory
    )
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
func quickPanelWindowCanBecomeKeyAndMain() {
    let panel = QuickPanelWindow(
        contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )

    #expect(panel.canBecomeKey)
    #expect(panel.canBecomeMain)
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
func storageMaintenanceKeepsManualBackupsBeyondAutomaticRetention() throws {
    let databaseManager = try makeDatabaseManager()
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
    let maintenanceService = StorageMaintenanceService(
        dbQueue: databaseManager.dbQueue,
        logRepository: logRepository,
        databaseURL: databaseManager.databaseURL
    )

    let backupTarget = Constants.automaticBackupRetentionCount + 2
    for _ in 0..<backupTarget {
        _ = try maintenanceService.createManualBackup()
    }

    let snapshot = try maintenanceService.healthSnapshot()
    #expect(snapshot.backupCount == backupTarget)
    #expect(snapshot.latestBackupURL != nil)
}

@Test
func launchMaintenanceDoesNotCreateExtraBackupAfterRecentManualBackup() throws {
    let databaseManager = try makeDatabaseManager()
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
    let maintenanceService = StorageMaintenanceService(
        dbQueue: databaseManager.dbQueue,
        logRepository: logRepository,
        databaseURL: databaseManager.databaseURL
    )

    let manualBackupURL = try maintenanceService.createManualBackup()
    let beforeSnapshot = try maintenanceService.healthSnapshot()

    _ = try maintenanceService.performLaunchMaintenance()

    let afterSnapshot = try maintenanceService.healthSnapshot()
    #expect(afterSnapshot.backupCount == beforeSnapshot.backupCount)
    #expect(afterSnapshot.latestBackupURL?.lastPathComponent == manualBackupURL.lastPathComponent)
}

@Test
func freshDatabaseDoesNotCreateUnusedTagsIndex() throws {
    let databaseManager = try makeDatabaseManager()
    let indexNames = try databaseManager.dbQueue.read { db in
        try Row.fetchAll(db, sql: "PRAGMA index_list('entries')")
            .compactMap { row in row["name"] as String? }
    }

    #expect(!indexNames.contains("index_entries_on_tags"))
}

@Test
func migrationsDropLegacyTagsIndex() throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")

    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(sql: """
            CREATE TABLE entries (
                id TEXT PRIMARY KEY NOT NULL,
                project_id TEXT NOT NULL,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                type TEXT NOT NULL,
                is_pinned INTEGER NOT NULL,
                sort_order INTEGER NOT NULL,
                use_count INTEGER NOT NULL,
                last_used_at TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                tags TEXT NOT NULL DEFAULT '[]'
            )
            """)
        try db.execute(sql: "CREATE INDEX index_entries_on_tags ON entries(tags)")
        try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT PRIMARY KEY NOT NULL)")
        for identifier in [
            "v1_create_tables",
            "v2_execution_log_diagnostics",
            "v3_execution_log_interaction_diagnostics",
            "v4_entry_tags"
        ] {
            try db.execute(
                sql: "INSERT INTO grdb_migrations(identifier) VALUES (?)",
                arguments: [identifier]
            )
        }
    }

    let databaseManager = try DatabaseManager(url: databaseURL)
    let indexNames = try databaseManager.dbQueue.read { db in
        try Row.fetchAll(db, sql: "PRAGMA index_list('entries')")
            .compactMap { row in row["name"] as String? }
    }

    #expect(!indexNames.contains("index_entries_on_tags"))
}

@Test
func logCleanupRemovesOnlyExpiredEntries() throws {
    let databaseManager = try makeDatabaseManager()
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)

    try logRepository.record(
        ExecutionLog(
            entryId: "recent",
            projectId: "project-1",
            hasAccessibility: true,
            clipboardSuccess: true,
            pasteAttempted: true,
            pasteSuccess: true,
            result: Constants.ExecutionResult.success.rawValue,
            createdAt: Date()
        )
    )
    try logRepository.record(
        ExecutionLog(
            entryId: "expired",
            projectId: "project-1",
            hasAccessibility: true,
            clipboardSuccess: true,
            pasteAttempted: false,
            pasteSuccess: false,
            result: Constants.ExecutionResult.clipboardOnly.rawValue,
            createdAt: Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? .distantPast
        )
    )

    try logRepository.cleanup(olderThanDays: 30)
    let remaining = try logRepository.fetchRecent(limit: 10)

    #expect(remaining.count == 1)
    #expect(remaining.first?.entryId == "recent")
}

@Test
func healthSummaryCountsResultsAcrossOutcomes() throws {
    let databaseManager = try makeDatabaseManager()
    let logRepository = LogRepository(dbQueue: databaseManager.dbQueue)
    let now = Date()

    try logRepository.record(
        ExecutionLog(
            entryId: "success",
            projectId: "project-1",
            hasAccessibility: true,
            clipboardSuccess: true,
            pasteAttempted: true,
            pasteSuccess: true,
            result: Constants.ExecutionResult.success.rawValue,
            createdAt: now
        )
    )
    try logRepository.record(
        ExecutionLog(
            entryId: "clipboard-only",
            projectId: "project-1",
            hasAccessibility: false,
            clipboardSuccess: true,
            pasteAttempted: false,
            pasteSuccess: false,
            result: Constants.ExecutionResult.clipboardOnly.rawValue,
            createdAt: now
        )
    )
    try logRepository.record(
        ExecutionLog(
            entryId: "failed",
            projectId: "project-1",
            hasAccessibility: true,
            clipboardSuccess: false,
            pasteAttempted: false,
            pasteSuccess: false,
            result: Constants.ExecutionResult.failed.rawValue,
            createdAt: now
        )
    )

    let summary = try logRepository.fetchHealthSummary(
        since: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast
    )

    #expect(summary.totalCount == 3)
    #expect(summary.successCount == 1)
    #expect(summary.clipboardOnlyCount == 1)
    #expect(summary.failedCount == 1)
    #expect(summary.latestExecutionAt != nil)
    #expect(summary.latestFailureAt != nil)
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

private final class FakeClipboardWriter: ClipboardWriting {
    private let success: Bool

    init(success: Bool) {
        self.success = success
    }

    func writeText(_ text: String) -> Bool {
        success
    }
}

private final class FakePasteDispatcher: PasteDispatching {
    private let result: PasteService.PasteDispatchResult
    private(set) var attemptCount: Int = 0

    init(result: PasteService.PasteDispatchResult) {
        self.result = result
    }

    func attemptPaste() -> PasteService.PasteDispatchResult {
        attemptCount += 1
        return result
    }
}

@MainActor
private final class FakePermissionProvider: AccessibilityPermissionProviding {
    private(set) var isAccessibilityGranted: Bool

    init(isAccessibilityGranted: Bool) {
        self.isAccessibilityGranted = isAccessibilityGranted
    }

    func refresh() {}
}

private func makeDatabaseManager() throws -> DatabaseManager {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")
    return try DatabaseManager(url: databaseURL)
}
