//
//  ViewerPickerView.swift
//  Yattee
//
//  A remote-friendly local viewer picker. Highlighting never changes selection.
//

import Foundation
import SwiftUI

#if os(tvOS)
struct ViewerPickerView: View {
    let manager: ViewerProfilesManager

    private enum FocusTarget: Hashable {
        case viewer(UUID)
        case rename(UUID)
        case add
        case close
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedControl: FocusTarget?
    @State private var editorReturnFocus: FocusTarget?
    @State private var showingEditor = false
    @State private var editingID: UUID?
    @State private var draftName = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 28) {
            Text("viewers.title")
                .font(.largeTitle)
            Text("viewers.sharedData")
                .font(.callout)
                .foregroundStyle(.secondary)

            if manager.storageUnavailable {
                Text(ViewerProfileError.unavailableStorage.localizedDescription)
                    .foregroundStyle(.red)
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("viewerPicker.error")
            }

            ScrollViewReader { proxy in
                ScrollView {
                    // All controls share one vertical focus path. In particular,
                    // Add spans both columns, directly below the last Rename.
                    // Eager rows keep offscreen scroll/focus targets addressable.
                    VStack(spacing: 32) {
                        ForEach(manager.profiles) { profile in
                            viewerRow(profile)
                        }

                        Button {
                            editingID = nil
                            draftName = ""
                            errorMessage = nil
                            editorReturnFocus = .add
                            showingEditor = true
                        } label: {
                            Text("viewers.add")
                                .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .disabled(manager.storageUnavailable)
                        .focused($focusedControl, equals: .add)
                        .id(FocusTarget.add)
                        .accessibilityIdentifier("viewerPicker.add")

                        Button {
                            dismiss()
                        } label: {
                            Text("common.close")
                                .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .focused($focusedControl, equals: .close)
                        .id(FocusTarget.close)
                        .accessibilityIdentifier("viewerPicker.close")
                    }
                    .padding(40)
                }
                .defaultFocus($focusedControl, editorReturnFocus ?? .viewer(manager.activeViewerID))
                .task(id: showingEditor) {
                    guard !showingEditor else { return }
                    // Run on initial presentation and after Save/Cancel/Back in
                    // the editor. Ordinary directional navigation never triggers
                    // this task. Cancellation prevents a late focus jump on exit.
                    let target = editorReturnFocus ?? .viewer(manager.activeViewerID)
                    proxy.scrollTo(target, anchor: .center)
                    do { try await Task.sleep(for: .milliseconds(150)) }
                    catch { return }
                    focusedControl = target
                }
            }
        }
        .padding(60)
        .background(Color.black.ignoresSafeArea())
        .onChange(of: focusedControl) { _, target in
            // Names/UUIDs are intentionally omitted from focus diagnostics.
            let control: String
            switch target {
            case .viewer: control = "viewer"
            case .rename: control = "rename"
            case .add: control = "add"
            case .close: control = "close"
            case nil: control = "none"
            }
            LoggingService.shared.debug("Viewer picker focus: \(control)", category: .general)
        }
        .onExitCommand {
            if !showingEditor { dismiss() }
        }
        .alert(
            editingID == nil ? String(localized: "viewers.add") : String(localized: "viewers.rename"),
            isPresented: $showingEditor
        ) {
            TextField(String(localized: "viewers.name"), text: $draftName)
            Button("common.save") {
                do {
                    if let editingID {
                        try manager.rename(id: editingID, name: draftName)
                    } else {
                        try manager.add(name: draftName)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("viewers.nameHelp")
        }
    }

    private func viewerRow(_ profile: ViewerProfile) -> some View {
        HStack(spacing: 32) {
            Button {
                do {
                    try manager.select(id: profile.id)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                HStack(spacing: 24) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                    Text(profile.name)
                        .font(.title3)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .opacity(profile.id == manager.activeViewerID ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            }
            .focused($focusedControl, equals: .viewer(profile.id))
            .id(FocusTarget.viewer(profile.id))
            .accessibilityLabel(profile.name)
            .accessibilityValue(profile.id == manager.activeViewerID ? String(localized: "viewers.active") : "")
            .accessibilityIdentifier("viewerPicker.select.\(profile.id)")

            Button {
                editingID = profile.id
                draftName = profile.name
                errorMessage = nil
                editorReturnFocus = .rename(profile.id)
                showingEditor = true
            } label: {
                Text("viewers.rename")
                    .frame(width: 220, height: 80)
            }
            .disabled(manager.storageUnavailable)
            .focused($focusedControl, equals: .rename(profile.id))
            .id(FocusTarget.rename(profile.id))
            .accessibilityIdentifier("viewerPicker.rename.\(profile.id)")
        }
    }
}
#endif
