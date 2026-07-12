import AppKit
import SwiftUI

enum CueFetchTheme {
    static let blue = Color(red: 0.10, green: 0.46, blue: 1.0)
    static let blueSoft = blue.opacity(0.14)
    static let border = Color.primary.opacity(0.14)
    static let divider = Color.primary.opacity(0.10)
    static let page = Color(nsColor: .windowBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let mutedText = Color.secondary
    static let orange = Color(red: 0.83, green: 0.36, blue: 0.0)
    static let green = Color(red: 0.15, green: 0.56, blue: 0.22)
    static let glassStroke = Color.white.opacity(0.20)
    static let orbitBackground = Color(red: 0.035, green: 0.055, blue: 0.085)
}

extension View {
    func cuePanel(radius: CGFloat = 8) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(CueFetchTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(CueFetchTheme.border, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    func cueGlassSurface(
        radius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: .rect(cornerRadius: radius)
            )
        } else {
            background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(CueFetchTheme.glassStroke, lineWidth: 1)
            }
        }
#else
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(CueFetchTheme.glassStroke, lineWidth: 1)
        }
#endif
    }

    @ViewBuilder
    func cueGlassCircle(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: .circle
            )
        } else {
            background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(CueFetchTheme.glassStroke, lineWidth: 1)
                }
        }
#else
        background(.ultraThinMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(CueFetchTheme.glassStroke, lineWidth: 1)
            }
#endif
    }

    @ViewBuilder
    func cueGlassButtonStyle() -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
#else
        buttonStyle(.bordered)
#endif
    }

    @ViewBuilder
    func cueProminentGlassButtonStyle() -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
#else
        buttonStyle(.borderedProminent)
#endif
    }
}

struct CueGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
#else
        content
#endif
    }
}
