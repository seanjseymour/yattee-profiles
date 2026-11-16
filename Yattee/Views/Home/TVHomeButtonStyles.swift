//
//  TVHomeButtonStyles.swift
//  Yattee
//
//  Button styles for tvOS Home view.
//

#if os(tvOS)
import SwiftUI

/// Button style for Home cards with scale + opacity focus effect.
struct TVHomeCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.tvDesignPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isFocused ? palette.accent : .clear, lineWidth: 3)
            }
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : (isFocused ? 1.025 : 1.0)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isFocused)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Button style for list rows with card background + focus effect.
struct TVHomeRowButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.tvDesignPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFocused ? palette.accent.opacity(0.14) : palette.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isFocused ? palette.accent : palette.border, lineWidth: isFocused ? 3 : 1)
            }
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : (isFocused ? 1.02 : 1.0)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isFocused)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
#endif
