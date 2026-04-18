import Foundation

/// Placeholder for Sparkle-based self-update capability.
/// Sparkle will be integrated in Step 14 (Release).
/// This stub ensures the rest of the codebase compiles cleanly.
@MainActor
final class UpdaterService: ObservableObject {

    /// Start the updater (no-op until Sparkle is integrated).
    func start() {
        PPLogger.updater.info("Updater not yet configured (Sparkle will be added in Step 14)")
    }

    /// Manual update check (no-op until Sparkle is integrated).
    func checkForUpdates() {
        PPLogger.updater.info("Update check not yet available")
    }
}
