//
//  ViewerWatchStoreTests.swift
//  YatteeTests
//
//  Synthetic isolation, ownership, preservation and bounded-recovery tests.
//

import Foundation
import Testing
#if canImport(Yattee)
@testable import Yattee
#else
@testable import ViewerHistoryCore
#endif

@Suite("Viewer watch isolation")
@MainActor
struct ViewerWatchStoreTests {
    private func fixture() -> (URL, UserDefaults, String) {
        let name = "ViewerWatchTests.\(UUID())"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathComponent("watch.json")
        return (url, UserDefaults(suiteName: name)!, name)
    }

    private func record(_ viewer: UUID, key: String = "source-A/video", seconds: Double, date: Date = Date()) -> ViewerWatchRecord {
        ViewerWatchRecord(viewerID: viewer, key: key, videoID: "video", sourceData: Data("{}".utf8),
                          title: "Synthetic title", authorName: "Fixture", authorID: "fixture", thumbnail: nil,
                          duration: 600, seconds: seconds, finished: false, live: false, createdAt: date, updatedAt: date)
    }

    @Test func sameVideoTwoViewersAndSourceScopes() throws {
        let (url, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let a = UUID(), b = UUID()
        let store = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        try store.save(record(a, seconds: 111))
        try store.save(record(b, seconds: 222))
        // A -> B -> A reads, independent of current selection or display name.
        #expect(store.history(viewerID: a).first?.seconds == 111)
        #expect(store.history(viewerID: b).first?.seconds == 222)
        #expect(store.history(viewerID: a).first?.seconds == 111)
        try store.save(record(a, key: "source-B/video", seconds: 333))
        #expect(store.history(viewerID: a).count == 2)
        #expect(store.record(viewerID: a, key: "source-A/video")?.seconds == 111)
        try store.remove(viewerID: b) { _ in true }
        #expect(store.history(viewerID: b).isEmpty)
        #expect(store.history(viewerID: a).count == 2)
        let relaunched = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        #expect(relaunched.history(viewerID: a).count == 2)
        #expect(relaunched.history(viewerID: b).isEmpty)
    }

    @Test func capturedOwnerSurvivesSwitchRetryAndLateClose() throws {
        let (url, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let a = UUID(), b = UUID()
        let store = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        var ownership = ViewerPlaybackOwnership()
        ownership.open(viewerID: a)
        let opening = try #require(ownership.session)
        // A quality reload / retry while B is selected retains the opening.
        ownership.load(viewerID: b)
        #expect(ownership.session == opening)
        try store.save(record(opening.viewerID, seconds: 130))
        #expect(store.history(viewerID: b).isEmpty)
        // A new explicit B opening has a distinct session. A queued final
        // write retains its captured owner; it cannot acquire B retroactively.
        ownership.open(viewerID: b)
        #expect(ownership.session?.id != opening.id)
        try store.save(record(b, seconds: 240))
        try store.save(record(opening.viewerID, seconds: 150))
        #expect(store.history(viewerID: a).first?.seconds == 150)
        #expect(store.history(viewerID: b).first?.seconds == 240)
        ownership.close()
        #expect(ownership.session == nil)
    }

    @Test func cacheLossRecoveryIsBoundedAndDoesNotResurrectRemoval() throws {
        let (url, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let a = UUID(), b = UUID()
        let store = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        for index in 0..<25 {
            try store.save(record(a, key: "source/\(index)", seconds: Double(index + 20), date: Date(timeIntervalSince1970: Double(index))))
        }
        try store.save(record(b, seconds: 200))
        try store.remove(viewerID: b) { _ in true }
        #expect(store.history(viewerID: a).count == 25)
        #expect(store.recoveryIsLimited)
        #expect(try #require(defaults.data(forKey: ViewerWatchStore.recoveryKey)).count <= ViewerWatchStore.recoveryByteLimit)
        try FileManager.default.removeItem(at: url)
        let recovered = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        #expect(recovered.recoveredFromCacheLoss)
        #expect(recovered.recoveryIsLimited)
        #expect(recovered.recoveryWasPartial)
        #expect(recovered.history(viewerID: a).count == ViewerWatchStore.recoveryEntriesPerViewer)
        #expect(recovered.history(viewerID: b).isEmpty)
        #expect(recovered.record(viewerID: a, key: "source/24")?.seconds == 44)
        try recovered.save(record(a, key: "source/24", seconds: 45))
        #expect(recovered.recoveryWasPartial, "Saving again must not erase the partial-recovery notice")
    }

    @Test func removalRevokesOnlyMatchingPlaybackPermits() throws {
        let (url, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let a = UUID(), b = UUID()
        let store = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        let old = store.writePermit(viewerID: a, key: "source-A/video")
        let otherSource = store.writePermit(viewerID: a, key: "source-B/video")
        let otherViewer = store.writePermit(viewerID: b, key: "source-A/video")
        try store.save(record(a, seconds: 111))
        try store.remove(viewerID: a) { $0.key == "source-A/video" }
        #expect(!store.accepts(old))
        #expect(store.accepts(otherSource))
        #expect(store.accepts(otherViewer))
        let reopened = store.writePermit(viewerID: a, key: "source-A/video")
        #expect(store.accepts(reopened))
        #expect(!store.accepts(old))
        // Clear also revokes openings that have not yet written a row.
        try store.remove(viewerID: a, invalidateAll: true) { _ in true }
        #expect(!store.accepts(reopened))
        #expect(!store.accepts(otherSource))
        #expect(store.accepts(otherViewer))
    }

    @Test func recoverySharesCapacityAndPrioritizesResume() throws {
        let (url, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let a = UUID(), b = UUID()
        let store = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        var inactive = record(b, seconds: 45, date: .distantPast)
        inactive.title = String(repeating: "b", count: 8000)
        try store.save(inactive)
        for index in 0..<22 {
            var busy = record(a, key: "source/\(index)", seconds: 600)
            busy.finished = true
            busy.title = String(repeating: "a", count: 8000)
            try store.save(busy)
        }
        try store.save(record(a, key: "active-resume", seconds: 70, date: .distantPast))
        var oversized = record(a, key: "oversized", seconds: 10)
        oversized.title = String(repeating: "x", count: 150 * 1024)
        try store.save(oversized)
        try FileManager.default.removeItem(at: url)
        let restored = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        #expect(restored.record(viewerID: b, key: "source-A/video")?.seconds == 45)
        #expect(restored.record(viewerID: a, key: "active-resume")?.seconds == 70)
        #expect(restored.recoveryWasPartial)
    }

    @Test func legacyAndUnknownNewerBytesAreNeverReplaced() throws {
        let (url, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let legacy = Data("Synthetic existing shared history".utf8)
        let legacyURL = url.deletingLastPathComponent().appendingPathComponent("legacy.store")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try legacy.write(to: legacyURL)
        defaults.set(legacy, forKey: "unrelated-existing-data")
        let store = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        #expect(store.records.isEmpty)
        try store.save(record(UUID(), seconds: 60))
        #expect(try Data(contentsOf: legacyURL) == legacy)
        #expect(defaults.data(forKey: "unrelated-existing-data") == legacy)
        let future = Data(#"{"version":99,"records":[]}"#.utf8)
        try future.write(to: url)
        let unavailable = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        #expect(unavailable.failure == .unreadable)
        #expect(throws: ViewerWatchStoreError.unreadable) { try unavailable.save(record(UUID(), seconds: 1)) }
        #expect(try Data(contentsOf: url) == future)
    }

    @Test func capacityFailureAndInvalidProgressLeavePriorState() throws {
        let (url, defaults, suite) = fixture()
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let a = UUID()
        let store = ViewerWatchStore(fileURL: url, defaults: defaults, defaultsDomainName: suite)
        try store.save(record(a, seconds: 60))
        let before = try Data(contentsOf: url)
        let backup = defaults.data(forKey: ViewerWatchStore.recoveryKey)
        #expect(throws: ViewerWatchStoreError.invalidProgress) { try store.save(record(a, seconds: .nan)) }
        defaults.set(Data(repeating: 1, count: 400 * 1024), forKey: "synthetic-capacity")
        #expect(throws: ViewerWatchStoreError.recoveryCapacity) { try store.save(record(a, seconds: 70)) }
        #expect(try Data(contentsOf: url) == before)
        #expect(defaults.data(forKey: ViewerWatchStore.recoveryKey) == backup)
        #expect(store.history(viewerID: a).first?.seconds == 60)
    }
}
