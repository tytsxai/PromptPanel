import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindow: NSWindow?

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

        do {
            try initializeDependencies()
            try wireApplication()
            permissionService.requestPermission()
            refreshPermissionState()
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
        storageMaintenanceService = StorageMaintenanceService(
            dbQueue: databaseManager.dbQueue,
            logRepository: logRepository,
            databaseURL: databaseManager.databaseURL
        )

        do {
            _ = try storageMaintenanceService.performLaunchMaintenance()
        } catch {
            PPLogger.database.error("Launch maintenance failed: \(error.localizedDescription)")
        }

        let currentProjectId = try settingsRepository.getCurrentProjectId()
        let defaultProject = try projectRepository.fetchDefault()

        appState.loadPersistedState(
            currentProjectId: currentProjectId,
            defaultProjectId: defaultProject?.id
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
        entrySearchService = EntrySearchService(entryRepository: entryRepository, appState: appState)

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
            launchRecoveryReport: databaseManager.launchRecoveryReport
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

    private func openMainWindow() {
        if mainWindow == nil {
            let contentView = MainWindowView(viewModel: mainWindowViewModel)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = Constants.appName
            window.center()
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            window.delegate = self
            mainWindow = window
        }

        mainWindowViewModel.load()
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appState.isMainWindowVisible = true
    }

    private func refreshPermissionState() {
        permissionService.refresh()
        appState.hasAccessibilityPermission = permissionService.isAccessibilityGranted
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
        }
    }
}
