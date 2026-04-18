import AppKit
import SwiftUI

@MainActor
final class ToastService {
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    func show(message: String, isSuccess: Bool) {
        let panel = panel ?? createPanel()
        panel.contentView = NSHostingView(rootView: ToastView(message: message, isSuccess: isSuccess))

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(
                NSPoint(
                    x: frame.maxX - size.width - 20,
                    y: frame.maxY - size.height - 20
                )
            )
        }

        panel.orderFrontRegardless()

        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: workItem)
    }

    private func createPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 88),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        self.panel = panel
        return panel
    }
}

private struct ToastView: View {
    let message: String
    let isSuccess: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(isSuccess ? .green : .orange)

            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}
