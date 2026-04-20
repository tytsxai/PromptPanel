import AppKit
import Foundation
import SwiftUI

/// Global constants for PromptPanel
enum Constants {
    private static let appSupportOverrideEnv = "PROMPTPANEL_APP_SUPPORT_DIR"
    private static let logsOverrideEnv = "PROMPTPANEL_LOGS_DIR"

    // MARK: - Visual system (PromptPanel front-end baseline)
    //
    // All colors are *dynamic*: they resolve at render time via
    // `NSColor(name:dynamicProvider:)`, so switching `.preferredColorScheme`
    // (or the system appearance) automatically re-renders every view without
    // any explicit bridging.
    //
    // Naming contract:
    //   - `bg / surface / surfaceRaised / surfaceHover / surfaceActive / sidebar`
    //     are concrete surface colors (do NOT flip sign).
    //   - `tintSubtle / tintMedium / tintStrong` are overlay tints that flip
    //     sign between themes (white in dark, black in light). Use these
    //     instead of hardcoded `Color.white.opacity(x)` / `Color.black.opacity(x)`.
    //   - `border / borderStrong / divider` are hairline dividers; they also
    //     flip sign so contrast stays legible.
    //   - `text / textSecondary / textTertiary / textQuaternary` are the
    //     text hierarchy; secondary/tertiary/quaternary get *more* contrast
    //     in light mode because light backgrounds need it.
    //   - `accent*`, `success*`, `warn*`, `danger*` are semantic colors; the
    //     solid tone is re-tuned for light mode so it stays readable, and the
    //     `*Dim` fill gets slightly more opacity so a light fill is visible.
    enum VisualStyle {
        // Surfaces
        static let bg              = dynamicColor(dark: 0x0e0f11, light: 0xf4f5f7)
        static let surface         = dynamicColor(dark: 0x17181b, light: 0xffffff)
        static let surfaceRaised   = dynamicColor(dark: 0x1e1f23, light: 0xf6f7f9)
        static let surfaceHover    = dynamicColor(dark: 0x24262b, light: 0xeceff3)
        static let surfaceActive   = dynamicColor(dark: 0x2b2e34, light: 0xe3e6ec)
        static let sidebar         = dynamicColor(dark: 0x141518, light: 0xeef0f4)

        // Dividers & borders (sign-flipping hairlines)
        static let border          = invertingTint(darkAlpha: 0.06, lightAlpha: 0.10)
        static let borderStrong    = invertingTint(darkAlpha: 0.10, lightAlpha: 0.14)
        static let divider         = invertingTint(darkAlpha: 0.04, lightAlpha: 0.07)

        // Text hierarchy
        static let text            = dynamicColor(dark: 0xe8e9ec, light: 0x1a1c20)
        static let textSecondary   = dynamicColor(dark: 0x9a9ea6, light: 0x4e525b)
        static let textTertiary    = dynamicColor(dark: 0x6b6f77, light: 0x7a7e87)
        static let textQuaternary  = dynamicColor(dark: 0x4a4d54, light: 0xadb1b9)

        // Accent (indigo 7c8cf8 — slightly deeper in light mode for contrast)
        static let accent          = dynamicColor(dark: 0x7c8cf8, light: 0x5667e6)
        static let accentDim       = semanticFill(dark: 0x7c8cf8, darkAlpha: 0.14, light: 0x5667e6, lightAlpha: 0.12)
        static let accentBorder    = semanticFill(dark: 0x7c8cf8, darkAlpha: 0.35, light: 0x5667e6, lightAlpha: 0.32)

        // Semantic (success / warn / danger)
        static let success         = dynamicColor(dark: 0x5fb37a, light: 0x2f8a4f)
        static let successDim      = semanticFill(dark: 0x5fb37a, darkAlpha: 0.12, light: 0x2f8a4f, lightAlpha: 0.14)
        static let warn            = dynamicColor(dark: 0xd4a35a, light: 0x9b6f1a)
        static let warnDim         = semanticFill(dark: 0xd4a35a, darkAlpha: 0.12, light: 0x9b6f1a, lightAlpha: 0.14)
        static let danger          = dynamicColor(dark: 0xd47070, light: 0xb63030)
        static let dangerDim       = semanticFill(dark: 0xd47070, darkAlpha: 0.12, light: 0xb63030, lightAlpha: 0.12)

        // Overlay tints — flip sign between themes. Use instead of
        // raw `Color.white.opacity(x)` / `Color.black.opacity(x)`.
        static let tintSubtle      = invertingTint(darkAlpha: 0.04, lightAlpha: 0.035)
        static let tintMedium      = invertingTint(darkAlpha: 0.06, lightAlpha: 0.05)
        static let tintStrong      = invertingTint(darkAlpha: 0.10, lightAlpha: 0.08)

        // Convenience: dark "scrim" used for panel footers — always darker
        // than the surface (black-tinted even in light mode).
        static let scrim           = semanticFill(dark: 0x000000, darkAlpha: 0.20, light: 0x000000, lightAlpha: 0.05)

        // MARK: - Dynamic color helpers

        /// Resolves `dark` / `light` hex values based on the current appearance.
        private static func dynamicColor(dark: UInt32, light: UInt32) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                nsColor(hex: appearance.isDark ? dark : light)
            })
        }

        /// Hairline tint that flips sign: white overlay in dark mode, black in
        /// light mode. Used for borders, dividers, and subtle fills.
        private static func invertingTint(darkAlpha: CGFloat, lightAlpha: CGFloat) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark
                    ? NSColor(srgbRed: 1, green: 1, blue: 1, alpha: darkAlpha)
                    : NSColor(srgbRed: 0, green: 0, blue: 0, alpha: lightAlpha)
            })
        }

        /// Semantic fill with per-mode hue + alpha.
        private static func semanticFill(dark: UInt32, darkAlpha: CGFloat, light: UInt32, lightAlpha: CGFloat) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark
                    ? nsColor(hex: dark, alpha: darkAlpha)
                    : nsColor(hex: light, alpha: lightAlpha)
            })
        }

        private static func nsColor(hex: UInt32, alpha: CGFloat = 1) -> NSColor {
            let r = CGFloat((hex >> 16) & 0xff) / 255
            let g = CGFloat((hex >> 8) & 0xff) / 255
            let b = CGFloat(hex & 0xff) / 255
            return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
        }
    }

    // MARK: - Application Identity

    static let appName = "PromptPanel"
    static let bundleIdentifier = "com.promptpanel.app"

    // MARK: - Data Directories

    static var applicationSupportDirectory: URL {
        let url = environmentURL(for: appSupportOverrideEnv)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var databaseURL: URL {
        applicationSupportDirectory.appendingPathComponent("promptpanel.db")
    }

    static func backupDirectory(for databaseURL: URL) -> URL {
        storageRoot(for: databaseURL).appendingPathComponent("Backups", isDirectory: true)
    }

    static func recoveryDirectory(for databaseURL: URL) -> URL {
        storageRoot(for: databaseURL).appendingPathComponent("Recovery", isDirectory: true)
    }

    // MARK: - Log Directories

    static var logsDirectory: URL {
        let url = environmentURL(for: logsOverrideEnv)
            ?? FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Logs")
                .appendingPathComponent(appName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static let automaticBackupRetentionCount = 7
    static let automaticBackupMinimumInterval: TimeInterval = 12 * 60 * 60
    static let executionLogRetentionDays = 30
    static let secureDirectoryPermissions = 0o700
    static let secureFilePermissions = 0o600

    // MARK: - Default Project

    static let defaultProjectName = "通用项目"

    // MARK: - Settings Keys

    enum SettingsKey {
        static let currentProjectId = "current_project_id"
        static let panelPinned = "panel_pinned"
        static let panelContentWidth = "panel_content_width"
        static let panelContentHeight = "panel_content_height"
        static let panelShowFooter = "panel_show_footer"
        static let panelCompactRows = "panel_compact_rows"
        static let appTheme = "app_theme"
    }

    // MARK: - Entry Types

    enum EntryType: String, CaseIterable, Codable {
        case prompt
        case code
        case reply
        case note

        var displayName: String {
            switch self {
            case .prompt: return "Prompt"
            case .code: return "代码"
            case .reply: return "回复"
            case .note: return "说明"
            }
        }

        var symbolName: String {
            switch self {
            case .prompt: return "text.bubble.fill"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .reply: return "arrowshape.turn.up.left.fill"
            case .note: return "note.text"
            }
        }

        var accentColor: Color {
            switch self {
            case .prompt: return Color(red: 0.36, green: 0.62, blue: 0.95)
            case .code: return Color(red: 0.36, green: 0.78, blue: 0.56)
            case .reply: return Color(red: 0.96, green: 0.65, blue: 0.30)
            case .note: return Color(red: 0.65, green: 0.55, blue: 0.86)
            }
        }

        static func resolve(_ rawValue: String?) -> EntryType {
            guard let rawValue, let parsed = EntryType(rawValue: rawValue) else {
                return .prompt
            }
            return parsed
        }
    }

    // MARK: - Execution Results

    enum ExecutionResult: String, Codable {
        case success
        case clipboardOnly = "clipboard_only"
        case failed
    }

    enum ExecutionTrigger: String, Codable {
        case keyboardSubmit = "keyboard_submit"
        case pointerClick = "pointer_click"
    }

    // MARK: - Panel Performance

    enum MainWindowLayout {
        static let defaultContentSize = NSSize(width: 1100, height: 740)
        static let minContentSize = NSSize(width: 1020, height: 680)
    }

    static let panelContentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    /// Unified default panel size (matches `frontend-draft/index.html` width=780).
    static let panelContentSize = NSSize(width: 780, height: 440)
    static let panelMinContentSize = NSSize(width: 560, height: 300)
    static let panelMaxContentSize = NSSize(width: 1120, height: 760)
    static func panelWindowContentSize(for panelContentSize: NSSize) -> NSSize {
        NSSize(
            width: panelContentSize.width + panelContentInsets.left + panelContentInsets.right,
            height: panelContentSize.height + panelContentInsets.top + panelContentInsets.bottom
        )
    }
    static var panelWindowSize: NSSize {
        panelWindowContentSize(for: panelContentSize)
    }
    static let panelOpenLatencyTargetMs = 300
    static let panelExecutionUnlockDelayMs = 50
    static let panelActivationRetryDelayMs = 60
    static let panelActivationMaxAttempts = 8
    static let panelFocusRetryDelayMs = 60
    static let panelFocusMaxAttempts = 10
    static let panelDeactivateCloseGraceMs = 900
    static let panelSearchDebounceMs = 80
    static let mainWindowSearchDebounceMs = 120
    static let searchLatencyTargetMs = 80
    static let executionLatencyTargetMs = 250
    static let targetAppRestorePollIntervalMs = 40
    static let targetAppRestoreTimeoutMs = 700

    enum ExecutionFailureReason: String, Codable {
        case clipboardWriteFailed = "clipboard_write_failed"
        case accessibilityNotGranted = "accessibility_not_granted"
        case targetAppNotRestored = "target_app_not_restored"
        case pasteEventCreationFailed = "paste_event_creation_failed"
    }

    private static func storageRoot(for databaseURL: URL) -> URL {
        let normalizedDatabaseURL = databaseURL.standardizedFileURL
        if normalizedDatabaseURL == self.databaseURL.standardizedFileURL {
            return applicationSupportDirectory
        }
        return normalizedDatabaseURL.deletingLastPathComponent()
    }

    private static func environmentURL(for key: String) -> URL? {
        let rawValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: rawValue, isDirectory: true)
    }
}

extension NSAppearance {
    /// True when the appearance resolves to a dark variant. Used by the
    /// dynamic color providers in `Constants.VisualStyle`.
    var isDark: Bool {
        bestMatch(from: [.aqua, .vibrantLight, .darkAqua, .vibrantDark]) == .darkAqua
            || bestMatch(from: [.aqua, .vibrantLight, .darkAqua, .vibrantDark]) == .vibrantDark
    }
}
