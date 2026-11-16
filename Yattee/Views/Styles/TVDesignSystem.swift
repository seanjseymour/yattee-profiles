//
//  TVDesignSystem.swift
//  Yattee
//
//  Semantic colour and focus treatment shared by the Apple TV themes.
//

import SwiftUI

#if os(tvOS)
struct TVDesignPalette: Sendable {
    let background: Color
    let surface: Color
    let foreground: Color
    let secondary: Color
    let accent: Color
    let border: Color
    let focusForeground: Color

    static func resolve(theme: TVDesignTheme, scheme: ColorScheme) -> Self {
        switch (theme, scheme) {
        case (.horizon, .dark):
            Self(background: rgb(0x0E171D), surface: rgb(0x1A272E),
                 foreground: rgb(0xF1F5F7), secondary: rgb(0xBAC9D0),
                 accent: rgb(0xC5EEEB), border: rgb(0x40535D), focusForeground: rgb(0x102D32))
        case (.horizon, _):
            Self(background: rgb(0xF1F6F6), surface: rgb(0xFFFFFF),
                 foreground: rgb(0x142F35), secondary: rgb(0x4E656B),
                 accent: rgb(0x175E65), border: rgb(0xAABFC3), focusForeground: rgb(0xFFFFFF))
        case (.slate, .dark):
            Self(background: rgb(0x17191E), surface: rgb(0x24272F),
                 foreground: rgb(0xF5F4F2), secondary: rgb(0xC2C4CB),
                 accent: rgb(0xF1CE9B), border: rgb(0x50515A), focusForeground: rgb(0x30200D))
        case (.slate, _):
            Self(background: rgb(0xF5F3F0), surface: rgb(0xFFFFFF),
                 foreground: rgb(0x292A30), secondary: rgb(0x60616B),
                 accent: rgb(0x7C511B), border: rgb(0xBDB8B1), focusForeground: rgb(0xFFFFFF))
        }
    }

    private static func rgb(_ value: UInt32) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 255) / 255,
              green: Double((value >> 8) & 255) / 255,
              blue: Double(value & 255) / 255, opacity: 1)
    }
}

private struct TVDesignPaletteKey: EnvironmentKey {
    static let defaultValue = TVDesignPalette.resolve(theme: .horizon, scheme: .light)
}

extension EnvironmentValues {
    var tvDesignPalette: TVDesignPalette {
        get { self[TVDesignPaletteKey.self] }
        set { self[TVDesignPaletteKey.self] = newValue }
    }
}

private struct TVDesignSurface: ViewModifier {
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let palette = TVDesignPalette.resolve(
            theme: appEnvironment?.settingsManager.tvDesignTheme ?? .horizon,
            scheme: colorScheme
        )
        content
            .environment(\.tvDesignPalette, palette)
            .foregroundStyle(palette.foreground)
            .tint(palette.accent)
            .accentColor(palette.accent)
            .background(palette.background.ignoresSafeArea())
    }
}

extension View {
    /// Uses the effective window appearance; System therefore remains dynamic.
    func tvDesignSurface() -> some View {
        modifier(TVDesignSurface())
    }
}

/// A restrained, high-contrast focus target for navigation and primary actions.
struct TVDesignButtonStyle: ButtonStyle {
    @Environment(\.tvDesignPalette) private var palette
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isFocused ? palette.focusForeground : palette.foreground)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(isFocused ? palette.accent : palette.surface,
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isFocused ? palette.accent : palette.border,
                                  lineWidth: isFocused ? 3 : 1)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : (isFocused ? 1.025 : 1)))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isFocused)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
#endif
