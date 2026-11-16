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
            // Give every root one dedicated viewer header. Search controls
            // and Settings rows start below it.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 100)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // Include the empty header in the content focus region so Left
            // from Viewer returns to content rather than the app sidebar.
            .focusSection()
            .safeAreaInset(edge: .trailing, spacing: 0) {
                if let viewers = appEnvironment?.viewerProfilesManager {
                    VStack(alignment: .trailing) {
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
                        .frame(width: 300)
                        Spacer(minLength: 0)
                    }
                    // Only the narrow gutter is reserved beside content. The
                    // header button extends left into the empty header above.
                    .frame(width: 60, alignment: .trailing)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.trailing, 60)
                    .padding(.vertical, 12)
                    // Keep the focus region adjacent, not layered over the
                    // content: overlapping regions don't connect on tvOS.
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
