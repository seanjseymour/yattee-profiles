//
//  DataManager+ViewerHistory.swift
//  Yattee
//
//  Adapts app-local viewer history without inserting it into the shared store.
//

import Foundation

extension VideoID {
    var watchHistoryKey: String {
        #if os(tvOS)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        // Include the full source, not just a bare video ID or a viewer name.
        let sourceBytes = (try? encoder.encode(source)) ?? Data()
        return sourceBytes.base64EncodedString() + ":" + videoID
        #else
        return videoID
        #endif
    }
}

extension ViewerWatchRecord {
    var watchEntry: WatchEntry? {
        guard let source = try? JSONDecoder().decode(ContentSource.self, from: sourceData) else { return nil }
        let video = Video(id: VideoID(source: source, videoID: videoID), title: title,
                          description: nil, author: Author(id: authorID, name: authorName),
                          duration: duration, publishedAt: nil, publishedText: nil,
                          viewCount: nil, likeCount: nil,
                          thumbnails: Thumbnail.fallbackChain(for: thumbnail.flatMap { URL(string: $0) }),
                          isLive: live, isUpcoming: false, scheduledStartTime: nil)
        let entry = WatchEntry.from(video: video)
        entry.watchedSeconds = seconds
        entry.isFinished = finished
        entry.createdAt = createdAt
        entry.updatedAt = updatedAt
        entry.finishedAt = finished ? updatedAt : nil
        return entry
    }
}

extension DataManager {
    var activeHistoryViewerID: UUID? { historyViewerID?() }

    func watchProgress(for id: VideoID, viewerID: UUID? = nil) -> TimeInterval? {
        if let store = viewerWatchStore {
            guard let owner = viewerID ?? activeHistoryViewerID else { return nil }
            return store.record(viewerID: owner, key: id.watchHistoryKey)?.seconds
        }
        return watchProgress(for: id.videoID)
    }

    func watchEntry(for id: VideoID) -> WatchEntry? {
        if let store = viewerWatchStore {
            guard let owner = activeHistoryViewerID else { return nil }
            return store.record(viewerID: owner, key: id.watchHistoryKey)?.watchEntry
        }
        return watchEntry(for: id.videoID)
    }

    func saveViewerProgress(for video: Video, seconds: Double, duration: Double?, isLive: Bool,
                            viewerID: UUID?, finished: Bool = false) -> Bool {
        guard let store = viewerWatchStore else { return false }
        // With the viewer store configured, failure to resolve an owner must
        // never fall through to the shared legacy store.
        guard let owner = viewerID ?? activeHistoryViewerID else { return true }
        do {
            let old = store.record(viewerID: owner, key: video.id.watchHistoryKey)
            let live = video.isLive || isLive
            let length = max(0, duration ?? (video.duration > 0 ? video.duration : old?.duration ?? 0))
            let record = ViewerWatchRecord(
                viewerID: owner, key: video.id.watchHistoryKey, videoID: video.id.videoID,
                sourceData: try JSONEncoder().encode(video.id.source),
                title: video.title, authorName: video.author.name, authorID: video.author.id,
                thumbnail: video.thumbnails.first?.url.absoluteString,
                duration: live ? 0 : length, seconds: live ? 0 : seconds,
                finished: !live && (finished || old?.finished == true || (length > 0 && seconds / length >= 0.9)),
                live: live, createdAt: old?.createdAt ?? Date(), updatedAt: Date())
            try store.save(record)
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
            // Always rebuild for the ACTIVE viewer, not the writer's owner.
            TopShelfSnapshotWriter.writeContinueWatching(dataManager: self)
        } catch {
            LoggingService.shared.error("Could not save viewer progress", category: .general)
        }
        return true
    }

    @discardableResult
    func removeViewerHistory(matching predicate: (ViewerWatchRecord) -> Bool) -> Bool {
        guard let store = viewerWatchStore else { return false }
        guard let owner = activeHistoryViewerID else { return true }
        do {
            try store.remove(viewerID: owner, matching: predicate)
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
            TopShelfSnapshotWriter.writeContinueWatching(dataManager: self)
        } catch {
            LoggingService.shared.error("Could not remove viewer progress", category: .general)
        }
        return true
    }

    func removeFromHistory(videoID: VideoID) {
        if removeViewerHistory(matching: { $0.key == videoID.watchHistoryKey }) { return }
        removeFromHistory(videoID: videoID.videoID)
    }

    func markAsUnwatched(videoID: VideoID) { removeFromHistory(videoID: videoID) }
}
