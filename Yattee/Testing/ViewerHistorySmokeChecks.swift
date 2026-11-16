// Synthetic simulator-only checks of the actual DataManager/Top Shelf adapters.
#if DEBUG && os(tvOS) && targetEnvironment(simulator)
import Foundation
import SwiftData

@MainActor
enum ViewerHistorySmokeChecks {
    static func run() throws {
        let suite = "ViewerHistoryIntegration.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let profiles = ViewerProfilesManager(defaults: defaults)
        let a = profiles.activeViewerID
        let b = try profiles.add(name: "Synthetic B").id
        let dm = try DataManager(inMemory: true)
        let legacy = WatchEntry(videoID: "legacy", sourceRawValue: "global", globalProvider: "youtube",
                                title: "Unassigned legacy", authorName: "Fixture", authorID: "fixture",
                                duration: 600, watchedSeconds: 333)
        dm.modelContext.insert(legacy)
        dm.save()
        let file = directory.appendingPathComponent("watch.json")
        dm.viewerWatchStore = ViewerWatchStore(fileURL: file, defaults: defaults, defaultsDomainName: suite)
        dm.historyViewerID = { profiles.activeViewerID }
        precondition(dm.watchHistory().isEmpty, "Legacy must remain unassigned")
        let video = WatchEntry(videoID: "same", sourceRawValue: "global", globalProvider: "youtube",
                               title: "Synthetic same video", authorName: "Fixture", authorID: "fixture", duration: 600).toVideo()
        dm.updateWatchProgressLocal(for: video, seconds: 111, viewerID: a)
        precondition(dm.watchProgress(for: video.id) == 111)
        try profiles.select(id: b)
        TopShelfSnapshotWriter.writeContinueWatching(dataManager: dm)
        precondition(dm.watchHistory().isEmpty)
        precondition(TopShelfSnapshot.read(section: .continueWatching).isEmpty, "B shelf must clear")
        dm.updateWatchProgress(for: video, seconds: 120, viewerID: a)
        precondition(dm.watchHistory().isEmpty, "Late A save must not populate B")
        precondition(TopShelfSnapshot.read(section: .continueWatching).isEmpty, "Late A save must not repopulate shelf")
        dm.updateWatchProgressLocal(for: video, seconds: 222, viewerID: b)
        precondition(dm.watchProgress(for: video.id) == 222)
        try profiles.select(id: a)
        precondition(dm.watchProgress(for: video.id) == 120)
        let other = WatchEntry(videoID: "same", sourceRawValue: "global", globalProvider: "other",
                               title: "Other source", authorName: "Fixture", authorID: "fixture", duration: 600).toVideo()
        dm.updateWatchProgressLocal(for: other, seconds: 444, viewerID: a)
        precondition(dm.watchHistoryCount() == 2)
        precondition(dm.watchEntriesMap()[video.id.watchHistoryKey]?.watchedSeconds == 120)
        precondition(dm.watchEntriesMap()[other.id.watchHistoryKey]?.watchedSeconds == 444)
        try profiles.select(id: b)
        dm.removeFromHistory(videoID: video.id)
        precondition(dm.watchHistoryCount() == 0)
        try profiles.select(id: a)
        precondition(dm.watchHistoryCount() == 2)
        dm.markAsWatched(video: video)
        precondition(dm.watchEntry(for: video.id)?.isFinished == true)
        precondition(dm.watchEntry(for: other.id)?.isFinished == false)
        try profiles.rename(id: a, name: "Renamed A")
        let relaunchedProfiles = ViewerProfilesManager(defaults: defaults)
        precondition(relaunchedProfiles.activeViewerID == a)
        dm.viewerWatchStore = ViewerWatchStore(fileURL: file, defaults: defaults, defaultsDomainName: suite)
        precondition(dm.watchProgress(for: other.id) == 444)
        try FileManager.default.removeItem(at: file)
        dm.viewerWatchStore = ViewerWatchStore(fileURL: file, defaults: defaults, defaultsDomainName: suite)
        precondition(dm.watchProgress(for: other.id) == 444)
        dm.clearWatchHistory()
        precondition(dm.watchHistoryCount() == 0)
        precondition(dm.legacyWatchHistory().count == 1)
        precondition(dm.allWatchEntries().first?.watchedSeconds == 333, "Original shared rows must be untouched")
    }
}
#endif
