import Foundation
import ServiceManagement

/// Manages login item (launch at startup) registration.
final class LoginItemService {

    /// Register this app to launch at login.
    func enable() throws {
        do {
            try SMAppService.mainApp.register()
            PPLogger.loginItem.info("Login item registered")
        } catch {
            PPLogger.loginItem.error("Failed to register login item: \(error.localizedDescription)")
            throw error
        }
    }

    /// Unregister this app from launching at login.
    func disable() throws {
        do {
            try SMAppService.mainApp.unregister()
            PPLogger.loginItem.info("Login item unregistered")
        } catch {
            PPLogger.loginItem.error("Failed to unregister login item: \(error.localizedDescription)")
            throw error
        }
    }

    /// Check if the app is currently registered as a login item.
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
