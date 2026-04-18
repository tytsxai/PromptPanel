import AppKit
import SwiftUI

struct KeyAwareSearchField: NSViewRepresentable {
    @Binding var text: String

    let placeholder: String
    let focusToken: Int
    let onMoveSelection: (QuickPanelViewModel.SelectionDirection) -> Void
    let onSubmit: () -> Void
    let onEscape: () -> Void

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
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.currentEditor()?.selectedRange = NSRange(location: nsView.stringValue.count, length: 0)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        var lastFocusToken: Int = -1

        init(text: Binding<String>) {
            self._text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else {
                return
            }
            text = field.stringValue
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
