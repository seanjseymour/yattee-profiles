//
//  TVViewerRoot.swift
//  Yattee
//
//  Consistent root header inside each tab's NavigationStack. Native sidebar
//  destinations remain available; pushed screens keep their own Back behaviour.
//

import SwiftUI

#if os(tvOS)
private struct TVViewerRoot: ViewModifier {
    let router: NavigationRouter
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.tvDesignPalette) private var palette
    @State private var showingPicker = false
    @FocusState private var launcherFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusSection()
            .safeAreaInset(edge: .top, spacing: 24) {
                header
            }
            .background(palette.background.ignoresSafeArea())
            .fullScreenCover(isPresented: $showingPicker, onDismiss: {
                launcherFocused = true
            }) {
                if let viewers = appEnvironment?.viewerProfilesManager {
                    ViewerPickerView(manager: viewers)
                }
            }
    }

    private var header: some View {
        VStack(spacing: 24) {
            HStack(spacing: 24) {
                Text("Yattee")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 24)
                navigationButton(.home)
                navigationButton(.search)
                navigationButton(.settings)
                Spacer(minLength: 24)
                if let viewers = appEnvironment?.viewerProfilesManager {
                    Button {
                        showingPicker = true
                    } label: {
                        Label(String(localized: "viewers.current \(viewers.activeViewer.name)"),
                              systemImage: "person.crop.circle")
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 340)
                    }
                    .buttonStyle(TVDesignButtonStyle())
                    .focused($launcherFocused)
                    .accessibilityIdentifier("viewerPicker.open")
                    .if(router.selection != .home) { button in
                        button.onExitCommand { router.select(.home) }
                    }
                }
            }
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 48)
        .padding(.top, 24)
        .foregroundStyle(palette.foreground)
        .background(palette.background)
        .focusSection()
    }

    private func navigationButton(_ item: SidebarItem) -> some View {
        Button {
            router.select(item)
        } label: {
            VStack(spacing: 8) {
                Text(item.title)
                    .font(.headline)
                Capsule()
                    .fill(router.selection == item ? palette.accent : Color.clear)
                    .frame(height: 3)
                    .accessibilityHidden(true)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(TVDesignButtonStyle())
        .accessibilityIdentifier("tv.header.\(item.id)")
        .accessibilityAddTraits(router.selection == item ? .isSelected : [])
        .if(router.selection != .home) { button in
            button.onExitCommand { router.select(.home) }
        }
    }
}
#endif

extension View {
    @ViewBuilder
    func tvViewerRoot(router: NavigationRouter) -> some View {
        #if os(tvOS)
        modifier(TVViewerRoot(router: router))
        #else
        self
        #endif
    }
}
