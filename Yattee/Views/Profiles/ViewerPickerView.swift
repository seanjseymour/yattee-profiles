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

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedViewerID: UUID?
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 40)], spacing: 40) {
                        ForEach(manager.profiles) { profile in
                            VStack(spacing: 20) {
                                Button {
                                    do {
                                        try manager.select(id: profile.id)
                                        dismiss()
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                } label: {
                                    VStack(spacing: 16) {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 70))
                                        Text(profile.name)
                                            .font(.title3)
                                            .lineLimit(2)
                                        Image(systemName: "checkmark.circle.fill")
                                            .opacity(profile.id == manager.activeViewerID ? 1 : 0)
                                            .accessibilityHidden(true)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                }
                                .focused($focusedViewerID, equals: profile.id)
                                .accessibilityLabel(profile.name)
                                .accessibilityValue(profile.id == manager.activeViewerID ? String(localized: "viewers.active") : "")
                                .accessibilityIdentifier("viewerPicker.select.\(profile.id)")

                                Button("viewers.rename") {
                                    editingID = profile.id
                                    draftName = profile.name
                                    errorMessage = nil
                                    showingEditor = true
                                }
                                .disabled(manager.storageUnavailable)
                            }
                            .id(profile.id)
                        }
                    }
                    .padding(40)
                }
                .task {
                    // Materialize an offscreen active card before asking tvOS
                    // to focus it; cancel the request if the picker disappears.
                    proxy.scrollTo(manager.activeViewerID, anchor: .center)
                    do { try await Task.sleep(for: .milliseconds(150)) }
                    catch { return }
                    focusedViewerID = manager.activeViewerID
                }
            }

            HStack(spacing: 40) {
                Button("viewers.add") {
                    editingID = nil
                    draftName = ""
                    errorMessage = nil
                    showingEditor = true
                }
                .disabled(manager.storageUnavailable)
                .accessibilityIdentifier("viewerPicker.add")

                Button("common.close") { dismiss() }
            }
        }
        .padding(60)
        .background(Color.black.ignoresSafeArea())
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
}
#endif
