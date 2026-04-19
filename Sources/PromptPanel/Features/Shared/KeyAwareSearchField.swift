import AppKit
import SwiftUI

struct KeyAwareSearchField: NSViewRepresentable {
    @Binding var text: String

    let placeholder: String
    let focusToken: Int
    let onMoveSelection: (QuickPanelViewModel.SelectionDirection) -> Void
    let onSubmit: () -> Void
    let onEscape: () -> Void
    let onFocusResolved: (PanelFocusResult) -> Void

    func makeNSView(context: Context) -> PromptSearchField {
        let field = PromptSearchField()
        field.delegate = context.coordinator
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.46)
            ]
        )
        field.font = .systemFont(ofSize: 14)
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
        field.keyHandler = { event in
            switch Int(event.keyCode) {
            case 126:
                onMoveSelection(.up)
                return true
            case 125:
                onMoveSelection(.down)
                return true
            case 36, 76:
                onSubmit()
                return true
            case 53:
                onEscape()
                return true
            default:
                return false
            }
        }
        return field
    }

    func updateNSView(_ nsView: PromptSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        context.coordinator.onMoveSelection = onMoveSelection
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onEscape = onEscape
        context.coordinator.focusResolveHandler = onFocusResolved

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            context.coordinator.scheduleFocus(
                on: nsView,
                focusToken: focusToken,
                onFocusResolved: onFocusResolved
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        var lastFocusToken: Int = -1
        var focusResolveHandler: ((PanelFocusResult) -> Void)?
        var onMoveSelection: ((QuickPanelViewModel.SelectionDirection) -> Void)?
        var onSubmit: (() -> Void)?
        var onEscape: (() -> Void)?
        private var reportedSuccessfulFocusToken: Int = -1

        init(text: Binding<String>) {
            self._text = text
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let field = notification.object as? PromptSearchField else {
                return
            }
            reportSuccessfulFocusIfNeeded(field: field, attempt: Constants.panelFocusMaxAttempts)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else {
                return
            }
            text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                onMoveSelection?(.up)
                return true
            case #selector(NSResponder.moveDown(_:)):
                onMoveSelection?(.down)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                onSubmit?()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                onEscape?()
                return true
            default:
                return false
            }
        }

        func scheduleFocus(
            on field: PromptSearchField,
            focusToken: Int,
            onFocusResolved: @escaping (PanelFocusResult) -> Void
        ) {
            focusResolveHandler = onFocusResolved
            reportedSuccessfulFocusToken = -1
            attemptFocus(
                on: field,
                focusToken: focusToken,
                remainingAttempts: Constants.panelFocusMaxAttempts,
                attempt: 0,
                onFocusResolved: onFocusResolved
            )
        }

        private func attemptFocus(
            on field: PromptSearchField,
            focusToken: Int,
            remainingAttempts: Int,
            attempt: Int,
            onFocusResolved: @escaping (PanelFocusResult) -> Void
        ) {
            let delayMs = attempt == 0 ? 0 : Constants.panelFocusRetryDelayMs
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self, weak field] in
                guard let self, let field else {
                    return
                }
                guard self.lastFocusToken == focusToken else {
                    return
                }

                self.activateWindowIfNeeded(for: field)
                _ = field.window?.makeFirstResponder(field)
                let focusResult = self.makeFocusResult(field: field, token: focusToken, attempt: attempt)

                if focusResult.succeeded {
                    field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
                    self.reportSuccessfulFocusIfNeeded(result: focusResult)
                } else if remainingAttempts > 0 {
                    self.attemptFocus(
                        on: field,
                        focusToken: focusToken,
                        remainingAttempts: remainingAttempts - 1,
                        attempt: attempt + 1,
                        onFocusResolved: onFocusResolved
                    )
                } else {
                    onFocusResolved(focusResult)
                }
            }
        }

        private func makeFocusResult(field: PromptSearchField, token: Int, attempt: Int) -> PanelFocusResult {
            let window = field.window
            let hasEditor = field.currentEditor() != nil
            let firstResponderMatches = window?.firstResponder === field
            let appIsActive = NSApp.isActive
            let windowIsVisible = window?.isVisible ?? false
            let windowIsKey = window?.isKeyWindow ?? false
            let windowIsMain = window?.isMainWindow ?? false
            return PanelFocusResult(
                token: token,
                succeeded: PanelFocusResult.interactionReady(
                    appIsActive: appIsActive,
                    windowIsVisible: windowIsVisible,
                    windowIsKey: windowIsKey,
                    firstResponderMatches: firstResponderMatches,
                    hasEditor: hasEditor
                ),
                attempt: attempt,
                appIsActive: appIsActive,
                windowIsVisible: windowIsVisible,
                windowIsKey: windowIsKey,
                windowIsMain: windowIsMain,
                firstResponderMatches: firstResponderMatches,
                hasEditor: hasEditor
            )
        }

        private func activateWindowIfNeeded(for field: PromptSearchField) {
            guard let window = field.window else {
                return
            }

            if NSApp.isActive == false {
                _ = NSRunningApplication.current.activate(options: [])
                NSApp.activate(ignoringOtherApps: true)
            }
            if window.isKeyWindow == false {
                window.makeKeyAndOrderFront(nil)
            }
            if window.isMainWindow == false {
                window.makeMain()
            }
        }

        private func reportSuccessfulFocusIfNeeded(field: PromptSearchField, attempt: Int) {
            guard lastFocusToken >= 0 else {
                return
            }
            let result = makeFocusResult(field: field, token: lastFocusToken, attempt: attempt)
            guard result.succeeded else {
                return
            }
            reportSuccessfulFocusIfNeeded(result: result)
        }

        private func reportSuccessfulFocusIfNeeded(result: PanelFocusResult) {
            guard reportedSuccessfulFocusToken != result.token else {
                return
            }
            guard let focusResolveHandler else {
                return
            }
            reportedSuccessfulFocusToken = result.token
            focusResolveHandler(result)
        }
    }
}

extension PanelFocusResult {
    static func interactionReady(
        appIsActive: Bool,
        windowIsVisible: Bool,
        windowIsKey: Bool,
        firstResponderMatches: Bool,
        hasEditor: Bool
    ) -> Bool {
        appIsActive && windowIsVisible && windowIsKey && (firstResponderMatches || hasEditor)
    }
}

final class PromptSearchField: NSSearchField {
    var keyHandler: ((NSEvent) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        applyAppearance(isFocused: true)
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        applyAppearance(isFocused: false)
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            applyAppearance(isFocused: true)
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            applyAppearance(isFocused: false)
        }
        return didResignFirstResponder
    }

    private func configureAppearance() {
        focusRingType = .none
        isBordered = false
        drawsBackground = false
        wantsLayer = true
        maximumRecents = 0
        recentsAutosaveName = nil
        translatesAutoresizingMaskIntoConstraints = false
        lineBreakMode = .byTruncatingTail
        cell?.usesSingleLineMode = true
        (cell as? NSSearchFieldCell)?.searchButtonCell = nil
        applyAppearance(isFocused: false)
    }

    private func applyAppearance(isFocused: Bool) {
        guard let layer else {
            return
        }

        let focusedBorderColor = NSColor.controlAccentColor.withAlphaComponent(0.12)
        let unfocusedBorderColor = NSColor.white.withAlphaComponent(0.06)
        let backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.036)

        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.backgroundColor = backgroundColor.cgColor
        layer.borderColor = (isFocused ? focusedBorderColor : unfocusedBorderColor).cgColor
        layer.shadowColor = focusedBorderColor.cgColor
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.shadowOffset = .zero
    }
}
