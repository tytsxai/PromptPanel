import Foundation
import SwiftUI

/// Central observable state for the application.
/// This is NOT a god-object: repositories, services, and window controllers remain separate.
/// AppState only holds the minimal cross-cutting state that multiple parts of the app need to observe.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Project State

    /// The ID of the currently active project.
    @Published var currentProjectId: String?

    /// The ID of the built-in default project ("通用项目"). Set once during initialization.
    @Published private(set) var defaultProjectId: String?

    // MARK: - Panel State

    @Published var isPanelVisible: Bool = false

    // MARK: - Main Window State

    @Published var isMainWindowVisible: Bool = false

    // MARK: - Permission State

    @Published var hasAccessibilityPermission: Bool = false

    // MARK: - Initialization

    init() {
        PPLogger.app.info("AppState initialized")
    }

    /// Called once after database is ready to load persisted state.
    func loadPersistedState(currentProjectId: String?, defaultProjectId: String?) {
        self.currentProjectId = currentProjectId
        self.defaultProjectId = defaultProjectId
        PPLogger.app.info("Persisted state loaded: currentProject=\(currentProjectId ?? "nil"), defaultProject=\(defaultProjectId ?? "nil")")
    }

    /// The effective project ID for panel display.
    /// Falls back to defaultProjectId if currentProjectId is nil.
    var effectiveProjectId: String {
        currentProjectId ?? defaultProjectId ?? ""
    }
}
