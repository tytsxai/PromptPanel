import Cocoa
import Combine
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

struct CurrentProjectSelectionResolution: Equatable {
    let projectId: String?
    let needsPersistence: Bool
    let repairReason: String?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static func resolveCurrentProjectSelection(
        persistedCurrentProjectId: String?,
        defaultProjectId: String?,
        currentProjectExists: (String) throws -> Bool
    ) rethrows -> CurrentProjectSelectionResolution {
        let normalizedCurrentProjectId = persistedCurrentProjectId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedCurrentProjectId,
           !normalizedCurrentProjectId.isEmpty,
           try currentProjectExists(normalizedCurrentProjectId) {
            let needsPersistence = normalizedCurrentProjectId != persistedCurrentProjectId
            return CurrentProjectSelectionResolution(
                projectId: normalizedCurrentProjectId,
                needsPersistence: needsPersistence,
                repairReason: needsPersistence ? "Normalized current project selection before loading persisted state." : nil
            )
        }

        let normalizedDefaultProjectId = defaultProjectId?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedDefaultProjectId, !normalizedDefaultProjectId.isEmpty else {
            return CurrentProjectSelectionResolution(
                projectId: nil,
                needsPersistence: false,
                repairReason: nil
            )
        }

        let repairReason: String
        if let normalizedCurrentProjectId, !normalizedCurrentProjectId.isEmpty {
            repairReason = "Current project \(normalizedCurrentProjectId) no longer exists; falling back to default project \(normalizedDefaultProjectId)."
        } else {
            repairReason = "Current project selection is missing; falling back to default project \(normalizedDefaultProjectId)."
        }

        return CurrentProjectSelectionResolution(
            projectId: normalizedDefaultProjectId,
            needsPersistence: normalizedDefaultProjectId != persistedCurrentProjectId,
            repairReason: repairReason
        )
    }

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
    private var themeCancellable: AnyCancellable?

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

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? Constants.bundleIdentifier
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let runningProcessIdentifiersProvider = {
            (runningInstances ?? AppLaunchCoordinator.runningInstances(bundleIdentifier: bundleIdentifier))
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

    func applicationDidBecomeActive(_ notification: Notification) {
        // Re-check accessibility on focus so the UI tracks grants/revokes the
        // user just made in System Settings, including the case where a fresh
        // install left a stale TCC entry that needs `tccutil reset`.
        guard permissionService != nil else { return }
        refreshPermissionState()
        mainWindowViewModel?.refreshPermissionState()
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

        let initializedProjectRepository = projectRepository!
        let defaultProject = try initializedProjectRepository.fetchDefault()
        let currentProjectResolution = try Self.resolveCurrentProjectSelection(
            persistedCurrentProjectId: try settingsRepository.getCurrentProjectId(),
            defaultProjectId: defaultProject?.id,
            currentProjectExists: { projectId in
                try initializedProjectRepository.fetchById(projectId) != nil
            }
        )
        if currentProjectResolution.needsPersistence, let repairedProjectId = currentProjectResolution.projectId {
            if let repairReason = currentProjectResolution.repairReason {
                PPLogger.project.warning("Repairing current project selection on launch: \(repairReason)")
            }
            try settingsRepository.setCurrentProjectId(repairedProjectId)
        }
        let isPanelPinned = try settingsRepository.isPanelPinned()
        let panelContentSize = try settingsRepository.getPanelContentSize()
        let panelWindowOrigin = try settingsRepository.getPanelWindowOrigin()
        let panelShowFooter = try settingsRepository.isPanelFooterVisible()
        let panelCompactRows = try settingsRepository.isPanelCompactRows()
        let appTheme = try settingsRepository.getAppTheme()

        appState.loadPersistedState(
            currentProjectId: currentProjectResolution.projectId,
            defaultProjectId: defaultProject?.id,
            isPanelPinned: isPanelPinned,
            panelContentSize: panelContentSize,
            panelWindowOrigin: panelWindowOrigin,
            panelShowFooter: panelShowFooter,
            panelCompactRows: panelCompactRows,
            appTheme: appTheme
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
            },
            onSetPanelContentSize: { [weak self] size in
                self?.updatePanelContentSize(size) ?? false
            }
        )

        panelService.contentViewProvider = { [weak self] in
            guard let self else { return NSView() }
            let view = QuickPanelView(viewModel: self.quickPanelViewModel)
                .environmentObject(self.appState)
            return QuickPanelHostingView(rootView: view)
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
        panelService.onPanelWindowOriginChanged = { [weak self] origin in
            do {
                try self?.settingsRepository.setPanelWindowOrigin(origin)
            } catch {
                PPLogger.panel.error("Failed to persist panel window origin: \(error.localizedDescription)")
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

        // Keep NSWindow / NSPanel chrome in sync with the user's theme.
        themeCancellable = appState.$appTheme
            .receive(on: RunLoop.main)
            .sink { [weak self] theme in
                self?.applyAppearance(theme)
            }
        applyAppearance(appState.appTheme)

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
        PPLogger.app.info("Scheduling QA auto-open for main window after \(delayMs) ms")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(delayMs, 0))) { [weak self] in
            guard let self else { return }
            self.openMainWindow(targetTab: targetTab)
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
            let windowChromeColor = NSColor(name: nil) { appearance in
                appearance.isDark
                    ? NSColor(srgbRed: 30 / 255, green: 31 / 255, blue: 35 / 255, alpha: 1)
                    : NSColor(srgbRed: 246 / 255, green: 247 / 255, blue: 249 / 255, alpha: 1)
            }
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
            window.titlebarAppearsTransparent = false
            window.isMovableByWindowBackground = true
            window.backgroundColor = windowChromeColor
            window.isOpaque = true
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

    /// Apply the user's theme choice to every NSWindow/NSPanel we own.
    ///
    /// SwiftUI's `.preferredColorScheme` covers the content hierarchy, but
    /// the NSWindow chrome (traffic lights / titlebar) and offscreen panels
    /// need an explicit `appearance` so that dynamic `NSColor` providers
    /// resolve consistently.
    private func applyAppearance(_ theme: AppTheme) {
        let appearance: NSAppearance? = {
            switch theme {
            case .system: return nil
            case .light:  return NSAppearance(named: .aqua)
            case .dark:   return NSAppearance(named: .darkAqua)
            }
        }()
        NSApp.appearance = appearance
        mainWindow?.appearance = appearance
        panelService?.setAppearance(appearance)
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

    private func updatePanelContentSize(_ size: NSSize) -> Bool {
        do {
            try settingsRepository.setPanelContentSize(size)
            let normalizedSize = try settingsRepository.getPanelContentSize()
            panelService.setContentSize(normalizedSize)
            return true
        } catch {
            PPLogger.panel.error("Failed to persist panel content size: \(error.localizedDescription)")
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

final class QuickPanelHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
