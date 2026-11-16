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
        let suite = "ViewerUIFixture.\(UUID())"
        environment.dataManager.viewerWatchStore = ViewerWatchStore(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(suite).appendingPathComponent("watch.json"),
            defaults: UserDefaults(suiteName: suite)!, defaultsDomainName: suite)
        for index in 0..<itemCount {
            let entry = WatchEntry(
                videoID: "focus-fixture-\(index)", sourceRawValue: "global",
                globalProvider: "youtube", title: "Focus fixture \(index)",
                authorName: "UI fixture", authorID: "fixture", duration: 600,
                watchedSeconds: 120
            )
            entry.updatedAt = Date(timeIntervalSince1970: 2_000_000_000 - Double(index))
            let owner = environment.viewerProfilesManager.profiles[0].id
            environment.dataManager.updateWatchProgressLocal(for: entry.toVideo(), seconds: 120, viewerID: owner)
            if var record = environment.dataManager.viewerWatchStore?.record(viewerID: owner, key: entry.videoIdentifier.watchHistoryKey) {
                record.updatedAt = entry.updatedAt
                try! environment.dataManager.viewerWatchStore?.save(record)
            }
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
        if ProcessInfo.processInfo.environment["YATTEE_HISTORY_SMOKE"] == "1" {
            do {
                try ViewerHistorySmokeChecks.run()
                let marker = WatchEntry(videoID: "history-integration-pass", sourceRawValue: "global", globalProvider: "youtube",
                                        title: "History isolation checks passed", authorName: "Fixture", authorID: "fixture", duration: 600)
                environment.dataManager.updateWatchProgressLocal(for: marker.toVideo(), seconds: 120)
            } catch { preconditionFailure("History integration fixture failed: \(error)") }
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
