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
    let topPadding: CGFloat
    @Environment(\.appEnvironment) private var appEnvironment
    @State private var showingPicker = false
    @FocusState private var launcherFocused: Bool

    func body(content: Content) -> some View {
        content
            // Native directional focus visits content tiles before this
            // adjacent, full-height trailing region. Both regions participate
            // so Left from the launcher can return to content below its height.
            .focusSection()
            .safeAreaInset(edge: .trailing, spacing: 0) {
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
                    .padding(.top, topPadding)
                    .padding(.bottom, 12)
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
    func tvViewerRoot(router: NavigationRouter, topPadding: CGFloat = 12) -> some View {
        #if os(tvOS)
        modifier(TVViewerRoot(router: router, topPadding: topPadding))
        #else
        self
        #endif
    }
}
