import SwiftUI

enum Design {
    static let rowCornerRadius: CGFloat = 6
    static let pillCornerRadius: CGFloat = 999
    static let cardCornerRadius: CGFloat = 10
    static let windowCornerRadius: CGFloat = 12
    static let popoverShadowRadius: CGFloat = 36
}

extension View {
    func fullHitTarget() -> some View {
        contentShape(Rectangle())
    }

    func roundedHitTarget(cornerRadius: CGFloat) -> some View {
        contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct KbdLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Constants.VisualStyle.textSecondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Constants.VisualStyle.tintMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Constants.VisualStyle.tintStrong, lineWidth: 0.5)
            )
    }
}

struct FilterChip: View {
    let label: String
    let systemImage: String?
    let count: Int?
    let isActive: Bool
    let action: () -> Void

    init(
        label: String,
        systemImage: String? = nil,
        count: Int? = nil,
        isActive: Bool,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.count = count
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10.5, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .opacity(0.8)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .foregroundStyle(isActive ? Constants.VisualStyle.accent : Constants.VisualStyle.textTertiary)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isActive ? Constants.VisualStyle.accentDim : Color.clear)
            )
            .roundedHitTarget(cornerRadius: 4)
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeading: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Constants.VisualStyle.textQuaternary)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let shortcut: String?
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        shortcut: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Constants.VisualStyle.accent)
            )
            .roundedHitTarget(cornerRadius: 6)
        }
        .buttonStyle(.plain)
    }
}

struct GhostActionButton: View {
    let title: String
    let systemImage: String?
    let shortcut: String?
    let tone: Tone
    let action: () -> Void

    enum Tone {
        case neutral
        case danger
    }

    init(
        title: String,
        systemImage: String? = nil,
        shortcut: String? = nil,
        tone: Tone = .neutral,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.tone = tone
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Constants.VisualStyle.textTertiary)
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Constants.VisualStyle.tintMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 0.5)
            )
            .roundedHitTarget(cornerRadius: 6)
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return Constants.VisualStyle.text
        case .danger: return Constants.VisualStyle.danger
        }
    }

    private var strokeColor: Color {
        switch tone {
        case .neutral: return Constants.VisualStyle.border
        case .danger: return Constants.VisualStyle.danger.opacity(0.3)
        }
    }
}

struct QuietIconButton: View {
    let systemImage: String
    let tint: Color?
    let help: String?
    let action: () -> Void

    init(systemImage: String, tint: Color? = nil, help: String? = nil, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tint = tint
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint ?? Constants.VisualStyle.textTertiary)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.clear)
                )
                .roundedHitTarget(cornerRadius: 5)
        }
        .buttonStyle(.plain)
        .help(help ?? "")
    }
}
