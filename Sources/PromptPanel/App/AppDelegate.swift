import Cocoa
import SwiftUI

struct AppInstanceDescriptor: Equatable {
    let processIdentifier: pid_t
}

enum AppLaunchCoordinator {
    static let allowExistingInstanceEnvironmentKey = "PROMPTPANEL_ALLOW_EXISTING_INSTANCE"
    static let duplicateInstanceSettleTimeoutMs = 2_000
    static let duplicateInstancePollIntervalMs = 100

    static func runningInstances(bundleIdentifier: String) -> [AppInstanceDescriptor] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .map { AppInstanceDescriptor(processIdentifier: $0.processIdentifier) }
    }

    static func shouldSkipDuplicateCheck(environment: [String: String]) -> Bool {
        environment[allowExistingInstanceEnvironmentKey] == "1"
    }

    static func duplicateProcessIdentifier(
        currentProcessIdentifier: pid_t,
        runningProcessIdentifiers: [pid_t]
    ) -> pid_t? {
        Array(Set(runningProcessIdentifiers))
            .filter { $0 != currentProcessIdentifier }
            .sorted()
            .first
    }

    static func duplicateProcessIdentifierAfterSettling(
        currentProcessIdentifier: pid_t,
        timeoutMs: Int = duplicateInstanceSettleTimeoutMs,
        pollIntervalMs: Int = duplicateInstancePollIntervalMs,
        runningProcessIdentifiersProvider: () -> [pid_t],
        sleep: (UInt32) -> Void = { usleep($0) }
    ) -> pid_t? {
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(max(timeoutMs, 0)) * 1_000_000
        let pollIntervalUs = UInt32(max(pollIntervalMs, 0) * 1_000)
        var duplicatePid = duplicateProcessIdentifier(
            currentProcessIdentifier: currentProcessIdentifier,
            runningProcessIdentifiers: runningProcessIdentifiersProvider()
        )

        while duplicatePid != nil && DispatchTime.now().uptimeNanoseconds < deadline {
            sleep(pollIntervalUs)
            duplicatePid = duplicateProcessIdentifier(
                currentProcessIdentifier: currentProcessIdentifier,
                runningProcessIdentifiers: runningProcessIdentifiersProvider()
            )
        }

        return duplicatePid
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindow: NSWindow?
    private let launchMaintenanceQueue = DispatchQueue(label: "PromptPanel.launch-maintenance", qos: .utility)

    private(set) var databaseManager: DatabaseManager!
    private(set) var appState: AppState!

    private(set) var projectRepository: ProjectRepository!
    private(set) var entryRepository: EntryRepository!
    private(set) var settingsRepository: SettingsRepository!
    private(set) var logRepository: LogRepository!

    private var permissionService: PermissionService!
    private var clipboardService: ClipboardService!
    private var pasteService: PasteService!
    private var loginItemService: LoginItemService!
    private var storageMaintenanceService: StorageMaintenanceService!
    private var updaterService: UpdaterService!

    private var executeService: ExecuteService!
    private var entrySearchService: EntrySearchService!
    private var panelService: PanelService!
    private var trayManager: TrayManager!
    private var hotkeyService: HotkeyService!
    private var toastService: ToastService!
    private var panelOpenTracker: PanelOpenTracker!

    private var quickPanelViewModel: QuickPanelViewModel!
    private var mainWindowViewModel: MainWindowViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        PPLogger.app.info("Application did finish launching")

        if terminateForExistingInstanceIfNeeded() {
            return
        }

        do {
            try initializeDependencies()
            try wireApplication()
            scheduleLaunchMaintenance()
            updaterService.start()
            refreshPermissionState()
            schedulePanelAutoOpenForQAIfNeeded()
            scheduleMainWindowAutoOpenForQAIfNeeded()
            presentLaunchRecoveryAlertIfNeeded()
        } catch {
            PPLogger.app.error("Failed to initialize: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "初始化失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    @discardableResult
    private func terminateForExistingInstanceIfNeeded(
        runningInstances: [AppInstanceDescriptor]? = nil
    ) -> Bool {
        if AppLaunchCoordinator.shouldSkipDuplicateCheck(environment: ProcessInfo.processInfo.environment) {
            PPLogger.app.notice("Skipping duplicate-instance termination because allow-existing-instance override is set")
            return false
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let runningProcessIdentifiersProvider = {
            (runningInstances ?? AppLaunchCoordinator.runningInstances(bundleIdentifier: Constants.bundleIdentifier))
                .map(\.processIdentifier)
        }
        guard let existingProcessIdentifier = AppLaunchCoordinator.duplicateProcessIdentifierAfterSettling(
            currentProcessIdentifier: currentProcessIdentifier,
            runningProcessIdentifiersProvider: runningProcessIdentifiersProvider
        ) else {
            return false
        }

        PPLogger.app.warning(
            "Detected duplicate PromptPanel instance current_pid=\(currentProcessIdentifier) existing_pid=\(existingProcessIdentifier); terminating newer process"
        )
        if let existingApplication = NSRunningApplication(processIdentifier: existingProcessIdentifier) {
            _ = existingApplication.activate(options: [])
        }
        NSApp.terminate(nil)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService?.stop()
        storageMaintenanceService?.prepareForTermination()
        PPLogger.app.info("Application will terminate")
    }

    private func initializeDependencies() throws {
        databaseManager = try DatabaseManager()
        appState = AppState()

        projectRepository = ProjectRepository(dbQueue: databaseManager.dbQueue)
        entryRepository = EntryRepository(dbQueue: databaseManager.dbQueue)
        settingsRepository = SettingsRepository(dbQueue: databaseManager.dbQueue)
        logRepository = LogRepository(dbQueue: databaseManager.dbQueue)

        permissionService = PermissionService()
        clipboardService = ClipboardService()
        pasteService = PasteService()
        loginItemService = LoginItemService()
        toastService = ToastService()
        panelOpenTracker = PanelOpenTracker()
        updaterService = UpdaterService()
        storageMaintenanceService = StorageMaintenanceService(
            dbQueue: databaseManager.dbQueue,
            logRepository: logRepository,
            databaseURL: databaseManager.databaseURL
        )

        let currentProjectId = try settingsRepository.getCurrentProjectId()
        let defaultProject = try projectRepository.fetchDefault()
        let isPanelPinned = try settingsRepository.isPanelPinned()
        let panelContentSize = try settingsRepository.getPanelContentSize()
        let panelShowFooter = try settingsRepository.isPanelFooterVisible()
        let panelCompactRows = try settingsRepository.isPanelCompactRows()

        appState.loadPersistedState(
            currentProjectId: currentProjectId,
            defaultProjectId: defaultProject?.id,
            isPanelPinned: isPanelPinned,
            panelContentSize: panelContentSize,
            panelShowFooter: panelShowFooter,
            panelCompactRows: panelCompactRows
        )
    }

    private func wireApplication() throws {
        panelService = PanelService(appState: appState, panelOpenTracker: panelOpenTracker)
        executeService = ExecuteService(
            clipboardService: clipboardService,
            pasteService: pasteService,
            entryRepository: entryRepository,
            logRepository: logRepository,
            permissionService: permissionService,
            targetApplicationProvider: { [weak self] in
                self?.panelService.targetApplicationBundleId()
            },
            currentFrontApplicationProvider: {
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            }
        )
        entrySearchService = EntrySearchService(entryRepository: entryRepository)

        executeService.onClosePanel = { [weak self] in
            self?.panelService.hide()
        }
        executeService.onShowNotification = { [weak self] message, isSuccess in
            self?.toastService.show(message: message, isSuccess: isSuccess)
        }

        quickPanelViewModel = QuickPanelViewModel(
            appState: appState,
            projectRepository: projectRepository,
            settingsRepository: settingsRepository,
            searchService: entrySearchService,
            executeService: executeService,
            permissionService: permissionService,
            panelOpenTracker: panelOpenTracker,
            onSetPanelPinned: { [weak self] isPinned in
                self?.updatePanelPinnedState(isPinned) ?? false
            },
            onOpenSettings: { [weak self] in
                self?.panelService.hide()
                self?.openMainWindow(targetTab: .settings)
            },
            onClosePanel: { [weak self] in
                self?.panelService.hide()
            }
        )

        mainWindowViewModel = MainWindowViewModel(
            appState: appState,
            projectRepository: projectRepository,
            entryRepository: entryRepository,
            settingsRepository: settingsRepository,
            logRepository: logRepository,
            permissionService: permissionService,
            loginItemService: loginItemService,
            storageMaintenanceService: storageMaintenanceService,
            updaterService: updaterService,
            launchRecoveryReport: databaseManager.launchRecoveryReport,
            onSetPanelPinned: { [weak self] isPinned in
                self?.updatePanelPinnedState(isPinned) ?? false
            }
        )

        panelService.contentViewProvider = { [weak self] in
            guard let self else { return NSView() }
            let view = QuickPanelView(viewModel: self.quickPanelViewModel)
                .environmentObject(self.appState)
            return NSHostingView(rootView: view)
        }
        panelService.onWillShow = { [weak self] in
            self?.quickPanelViewModel.prepareForPresentation()
        }
        panelService.onDidStabilizeActivation = { [weak self] in
            self?.quickPanelViewModel.retryFocusAfterActivationStabilized()
        }
        panelService.onPanelContentSizeChanged = { [weak self] size in
            do {
                try self?.settingsRepository.setPanelContentSize(size)
            } catch {
                PPLogger.panel.error("Failed to persist panel content size: \(error.localizedDescription)")
            }
        }

        trayManager = TrayManager(
            onOpenMainWindow: { [weak self] in
                self?.openMainWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        trayManager.setup()

        hotkeyService = HotkeyService(
            onTogglePanel: { [weak self] in
                self?.panelService.toggle()
            },
            panelOpenTracker: panelOpenTracker
        )
        hotkeyService.start()
    }

    private func scheduleLaunchMaintenance() {
        guard let storageMaintenanceService = storageMaintenanceService else {
            return
        }

        launchMaintenanceQueue.async { [weak self, storageMaintenanceService] in
            guard let self else {
                return
            }

            do {
                _ = try storageMaintenanceService.performLaunchMaintenance()
                DispatchQueue.main.async {
                    self.mainWindowViewModel?.refreshOperationalStatus()
                }
            } catch {
                PPLogger.database.error("Launch maintenance failed: \(error.localizedDescription)")
            }
        }
    }

    private func schedulePanelAutoOpenForQAIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        guard let rawValue = environment["PROMPTPANEL_QA_OPEN_PANEL_ON_LAUNCH"]?.lowercased(),
              ["1", "true", "yes"].contains(rawValue) else {
            return
        }

        let delayMs = Int(environment["PROMPTPANEL_QA_OPEN_PANEL_DELAY_MS"] ?? "") ?? 700
        PPLogger.panel.info("Scheduling QA auto-open for panel after \(delayMs) ms")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(delayMs, 0))) { [weak self] in
            guard let self else {
                return
            }
            guard self.appState.isPanelVisible == false else {
                return
            }
            self.panelService.show()
        }
    }

    private func scheduleMainWindowAutoOpenForQAIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        guard let rawValue = environment["PROMPTPANEL_QA_OPEN_MAIN_WINDOW_ON_LAUNCH"]?.lowercased(),
              ["1", "true", "yes"].contains(rawValue) else {
            return
        }

        let delayMs = Int(environment["PROMPTPANEL_QA_OPEN_MAIN_WINDOW_DELAY_MS"] ?? "") ?? 500
        let targetTab = qaMainWindowTargetTab(from: environment["PROMPTPANEL_QA_MAIN_WINDOW_TAB"])
        let targetSection = qaSettingsSection(from: environment["PROMPTPANEL_QA_SETTINGS_SECTION"])
        PPLogger.app.info("Scheduling QA auto-open for main window after \(delayMs) ms")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(delayMs, 0))) { [weak self] in
            guard let self else { return }
            if let targetSection {
                self.mainWindowViewModel.settingsSection = targetSection
            }
            self.openMainWindow(targetTab: targetTab)
        }
    }

    private func qaSettingsSection(from rawValue: String?) -> MainWindowViewModel.SettingsSection? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !rawValue.isEmpty else {
            return nil
        }
        switch rawValue {
        case "general":
            return .general
        case "backup":
            return .backup
        case "about":
            return .about
        default:
            return nil
        }
    }

    private func qaMainWindowTargetTab(from rawValue: String?) -> MainWindowViewModel.Tab? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !rawValue.isEmpty else {
            return nil
        }

        switch rawValue {
        case "library", "content", "contents":
            return .library
        case "settings", "setting":
            return .settings
        default:
            return nil
        }
    }

    private func openMainWindow(targetTab: MainWindowViewModel.Tab? = nil) {
        if let targetTab {
            mainWindowViewModel.selectedTab = targetTab
        }
        if mainWindow == nil {
            let contentView = MainWindowView(viewModel: mainWindowViewModel)
            let defaultSize = Constants.MainWindowLayout.defaultContentSize
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: defaultSize.width, height: defaultSize.height),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = Constants.appName
            window.center()
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.delegate = self
            mainWindow = window
        }

        mainWindowViewModel.load()
        appState.isMainWindowVisible = true
        updateAppActivationPolicy()
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshPermissionState() {
        permissionService.refresh()
        appState.hasAccessibilityPermission = permissionService.isAccessibilityGranted
    }

    private func updatePanelPinnedState(_ isPinned: Bool) -> Bool {
        do {
            try settingsRepository.setPanelPinned(isPinned)
            panelService.setPinned(isPinned)
            return true
        } catch {
            PPLogger.panel.error("Failed to persist panel pinned state: \(error.localizedDescription)")
            return false
        }
    }

    private func presentLaunchRecoveryAlertIfNeeded() {
        guard let report = databaseManager.launchRecoveryReport else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "已恢复本地数据库可用状态"
        alert.informativeText = """
        上次启动时检测到数据库异常，原文件已隔离到：
        \(report.quarantinedFilesDirectoryURL.path)

        触发原因：
        \(report.failureDescription)

        请优先检查最近备份，并在主界面的“运行健康”中确认当前数据目录与备份状态。
        """
        alert.alertStyle = .warning
        alert.runModal()
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == mainWindow {
            appState.isMainWindowVisible = false
            updateAppActivationPolicy()
        }
    }

    private func updateAppActivationPolicy() {
        let desiredPolicy = PanelService.desiredActivationPolicy(
            isPanelVisible: appState.isPanelVisible,
            isMainWindowVisible: appState.isMainWindowVisible
        )

        guard NSApp.activationPolicy() != desiredPolicy else {
            return
        }

        guard NSApp.setActivationPolicy(desiredPolicy) else {
            PPLogger.app.error("Failed to switch activation policy to \(String(describing: desiredPolicy))")
            return
        }

        PPLogger.app.info("Switched activation policy to \(String(describing: desiredPolicy))")
    }
}
