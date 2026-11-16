//
//  ViewerFocusUITestFixture.swift
//  Yattee
//
//  Explicit, simulator-only fixture for real Home remote-navigation UI tests.
//

#if DEBUG && os(tvOS) && targetEnvironment(simulator)
import Foundation
import SwiftData

@MainActor
enum ViewerFocusUITestFixture {
    nonisolated static var itemCount: Int? {
        guard let value = ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_ITEMS"],
              let count = Int(value), (0...5).contains(count) else { return nil }
        return count
    }

    static func configure(_ environment: AppEnvironment, itemCount: Int) {
        let settings = environment.settingsManager
        settings.iCloudSyncEnabled = false
        settings.homeSectionLayout = .grid
        settings.homeSectionVisibility = Dictionary(uniqueKeysWithValues:
            HomeSectionItem.defaultOrder.map { ($0, $0 == .continueWatching) })
        for index in 0..<itemCount {
            let entry = WatchEntry(
                videoID: "focus-fixture-\(index)", sourceRawValue: "global",
                globalProvider: "youtube", title: "Focus fixture \(index)",
                authorName: "UI fixture", authorID: "fixture", duration: 600,
                watchedSeconds: 120
            )
            entry.updatedAt = Date(timeIntervalSince1970: 2_000_000_000 - Double(index))
            environment.dataManager.modelContext.insert(entry)
        }
        environment.dataManager.save()
        let viewers = environment.viewerProfilesManager
        do {
            try viewers.rename(id: viewers.profiles[0].id, name: ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_VIEWER_NAME"] ?? "Alpha")
            if !viewers.profiles.contains(where: { $0.name == "Beta" }) {
                try viewers.add(name: "Beta")
            }
            try viewers.select(id: viewers.profiles[0].id)
        } catch {
            preconditionFailure("Invalid isolated UI-test viewer fixture: \(error)")
        }
        if ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_SETTINGS"] == "1" {
            environment.navigationCoordinator.router.applyStartupTabIfNeeded(.settings)
        } else if ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_SEARCH"] == "1" {
            environment.navigationCoordinator.router.applyStartupTabIfNeeded(.search)
        } else if ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_SOURCES"] == "1" {
            environment.navigationCoordinator.router.applyStartupTabIfNeeded(.sources)
        }
    }
}
#endif
