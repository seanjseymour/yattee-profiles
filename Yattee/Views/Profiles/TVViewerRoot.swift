//
//  TVViewerRoot.swift
//  Yattee
//
//  Viewer access within each tab's root, inside its NavigationStack.
//

import SwiftUI

#if os(tvOS)
private struct TVViewerRoot: ViewModifier {
    let router: NavigationRouter
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var showingPicker = false
    @FocusState private var launcherFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusSection()
            // Give every root one dedicated viewer header. The content keeps
            // its full width; Search controls and Settings rows start below it.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 100)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                if let viewers = appEnvironment?.viewerProfilesManager {
                    VStack {
                        Button {
                            showingPicker = true
                        } label: {
                            Label(String(localized: "viewers.current \(viewers.activeViewer.name)"), systemImage: "person.crop.circle")
                                .lineLimit(1)
                        }
                        .focused($launcherFocused)
                        .accessibilityIdentifier("viewerPicker.open")
                        // Only this root control owns this fallback. Pushed
                        // details don't include the root chrome; sheets and
                        // editors own their own Back. True Home remains native.
                        .if(router.selection != .home) { button in
                            button.onExitCommand { router.select(.home) }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: 300)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.trailing, 60)
                    .padding(.vertical, 12)
                    // The transparent remainder is a native focus region,
                    // not a content column or a gesture interceptor. It lets
                    // Right from a shelf reach the header after its last tile.
                    .focusSection()
                }
            }
            .fullScreenCover(isPresented: $showingPicker, onDismiss: {
                launcherFocused = true
            }) {
                if let viewers = appEnvironment?.viewerProfilesManager {
                    ViewerPickerView(manager: viewers)
                }
            }
            .onChange(of: launcherFocused) { _, focused in
                LoggingService.shared.debug("Viewer launcher focused: \(focused)", category: .general)
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
