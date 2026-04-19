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
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 15)
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
        field.focusRingType = .default
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
        private var reportedFocusToken: Int = -1

        init(text: Binding<String>) {
            self._text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else {
                return
            }
            text = field.stringValue
        }

        func scheduleFocus(
            on field: PromptSearchField,
            focusToken: Int,
            onFocusResolved: @escaping (PanelFocusResult) -> Void
        ) {
            reportedFocusToken = -1
            attemptFocus(
                on: field,
                focusToken: focusToken,
                remainingAttempts: 2,
                onFocusResolved: onFocusResolved
            )
        }

        private func attemptFocus(
            on field: PromptSearchField,
            focusToken: Int,
            remainingAttempts: Int,
            onFocusResolved: @escaping (PanelFocusResult) -> Void
        ) {
            DispatchQueue.main.asyncAfter(deadline: .now() + (remainingAttempts == 2 ? 0 : 0.02)) { [weak self, weak field] in
                guard let self, let field else {
                    return
                }
                guard self.lastFocusToken == focusToken else {
                    return
                }

                _ = field.window?.makeFirstResponder(field)
                let focusSucceeded = field.currentEditor() != nil || field.window?.firstResponder === field

                if focusSucceeded {
                    field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
                    self.reportFocusIfNeeded(token: focusToken, succeeded: true, onFocusResolved: onFocusResolved)
                } else if remainingAttempts > 0 {
                    self.attemptFocus(
                        on: field,
                        focusToken: focusToken,
                        remainingAttempts: remainingAttempts - 1,
                        onFocusResolved: onFocusResolved
                    )
                } else {
                    self.reportFocusIfNeeded(token: focusToken, succeeded: false, onFocusResolved: onFocusResolved)
                }
            }
        }

        private func reportFocusIfNeeded(
            token: Int,
            succeeded: Bool,
            onFocusResolved: (PanelFocusResult) -> Void
        ) {
            guard reportedFocusToken != token else {
                return
            }
            reportedFocusToken = token
            onFocusResolved(PanelFocusResult(token: token, succeeded: succeeded))
        }
    }
}

final class PromptSearchField: NSSearchField {
    var keyHandler: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}
