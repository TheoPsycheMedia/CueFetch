import SwiftUI

enum CueFetchTheme {
    static let blue = Color(red: 0.0, green: 0.38, blue: 0.86)
    static let blueSoft = Color(red: 0.92, green: 0.96, blue: 1.0)
    static let border = Color.black.opacity(0.12)
    static let divider = Color.black.opacity(0.09)
    static let page = Color(red: 0.965, green: 0.972, blue: 0.982)
    static let panel = Color.white
    static let mutedText = Color.black.opacity(0.56)
    static let orange = Color(red: 0.83, green: 0.36, blue: 0.0)
    static let green = Color(red: 0.15, green: 0.56, blue: 0.22)
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
}
