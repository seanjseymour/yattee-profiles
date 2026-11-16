//
//  ViewerWatchStore.swift
//  Yattee
//
//  Local viewer progress, isolated from legacy SwiftData and shared sync IDs.
//

import Foundation
import Observation

struct ViewerWatchRecord: Codable, Equatable, Sendable {
    let viewerID: UUID
    let key: String
    let videoID: String
    let sourceData: Data
    var title: String
    var authorName: String
    var authorID: String
    var thumbnail: String?
    var duration: Double
    var seconds: Double
    var finished: Bool
    var live: Bool
    var createdAt: Date
    var updatedAt: Date
}

enum ViewerWatchStoreError: Error, LocalizedError, Equatable {
    case unreadable, recoveryCapacity, writeFailed, invalidProgress

    var errorDescription: String? {
        switch self {
        case .unreadable: "Viewer history could not be read. Existing data has been preserved."
        case .recoveryCapacity: "Viewer progress could not be saved because local recovery storage is full."
        case .writeFailed: "Viewer progress could not be saved."
        case .invalidProgress: "Invalid playback progress was not saved."
        }
    }
}

@MainActor
@Observable
final class ViewerWatchStore {
    struct WritePermit: Sendable {
        let viewerID: UUID
        let key: String
        fileprivate let revision: UUID
    }
    @ObservationIgnored private var writeRevisions: [UUID: [String: UUID]] = [:]

    func writePermit(viewerID: UUID, key: String) -> WritePermit {
        let revision = writeRevisions[viewerID]?[key] ?? UUID()
        writeRevisions[viewerID, default: [:]][key] = revision
        return WritePermit(viewerID: viewerID, key: key, revision: revision)
    }

    func accepts(_ permit: WritePermit) -> Bool {
        writeRevisions[permit.viewerID]?[permit.key] == permit.revision
    }

    static let recoveryKey = "yatteeProfiles.viewerWatchRecovery.v1"
    static let recoveryByteLimit = 128 * 1024
    static let recoveryEntriesPerViewer = 20
    private struct Snapshot: Codable {
        var version = 1
        var records: [ViewerWatchRecord]
        var incompleteRecovery = false
    }

    private(set) var records: [ViewerWatchRecord] = []
    private(set) var recoveredFromCacheLoss = false
    private(set) var recoveryWasPartial = false
    private(set) var recoveryIsLimited = false
    private(set) var failure: ViewerWatchStoreError?
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let defaultsDomainName: String?
    @ObservationIgnored private var writable = true

    init(fileURL: URL, defaults: UserDefaults = .standard, defaultsDomainName: String? = Bundle.main.bundleIdentifier) {
        self.fileURL = fileURL
        self.defaults = defaults
        self.defaultsDomainName = defaultsDomainName
        let bytes: Data?
        if FileManager.default.fileExists(atPath: fileURL.path) {
            bytes = try? Data(contentsOf: fileURL)
        } else if defaults.object(forKey: Self.recoveryKey) != nil {
            bytes = defaults.data(forKey: Self.recoveryKey)
            recoveredFromCacheLoss = true
        } else {
            return
        }
        guard let bytes,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: bytes),
              snapshot.version == 1,
              snapshot.records.allSatisfy(Self.valid),
              Set(snapshot.records.map { "\($0.viewerID)|\($0.key)" }).count == snapshot.records.count else {
            writable = false
            failure = .unreadable
            return
        }
        records = snapshot.records
        recoveryWasPartial = recoveredFromCacheLoss && snapshot.incompleteRecovery
        recoveryIsLimited = snapshot.incompleteRecovery
        if !recoveredFromCacheLoss,
           let backup = defaults.data(forKey: Self.recoveryKey),
           let recovery = try? JSONDecoder().decode(Snapshot.self, from: backup) {
            recoveryIsLimited = recovery.incompleteRecovery
        }
    }

    func history(viewerID: UUID) -> [ViewerWatchRecord] {
        records.filter { $0.viewerID == viewerID }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func record(viewerID: UUID, key: String) -> ViewerWatchRecord? {
        records.first { $0.viewerID == viewerID && $0.key == key }
    }

    func save(_ record: ViewerWatchRecord) throws {
        guard Self.valid(record) else { throw ViewerWatchStoreError.invalidProgress }
        var next = records.filter { !($0.viewerID == record.viewerID && $0.key == record.key) }
        next.append(record)
        try commit(next)
    }

    func remove(viewerID: UUID, invalidatingKeys: [String] = [], invalidateAll: Bool = false,
                matching predicate: (ViewerWatchRecord) -> Bool) throws {
        let removed = records.filter { $0.viewerID == viewerID && predicate($0) }
        let keys = Set(removed.map(\.key) + invalidatingKeys +
                       (invalidateAll ? Array(writeRevisions[viewerID, default: [:]].keys) : []))
        try commit(records.filter { $0.viewerID != viewerID || !predicate($0) }, removing: true)
        // Revoke only after a successful removal. A later explicit opening
        // acquires the new revision; retries retain the revoked permit.
        for key in keys { writeRevisions[viewerID, default: [:]][key] = UUID() }
    }

    private nonisolated static func valid(_ record: ViewerWatchRecord) -> Bool {
        !record.key.isEmpty && !record.videoID.isEmpty &&
        record.seconds.isFinite && record.seconds >= 0 && record.duration.isFinite && record.duration >= 0
    }

    private func commit(_ next: [ViewerWatchRecord], removing: Bool = false) throws {
        guard writable else { throw ViewerWatchStoreError.unreadable }
        do {
            let encoder = JSONEncoder()
            let full = try encoder.encode(Snapshot(records: next))
            // A small, bounded recovery set; the primary file retains older
            // history. Never discard another viewer's primary records to fit it.
            // Round-robin viewers, prioritizing unfinished resume records
            // within each viewer. A busy viewer cannot consume all slots before
            // an inactive viewer is considered. The byte cap remains a maximum.
            let grouped = Dictionary(grouping: next, by: \.viewerID)
            let viewers = grouped.keys.sorted { $0.uuidString < $1.uuidString }
            let queues = viewers.map { viewer in
                grouped[viewer, default: []].sorted {
                    let leftResume = !$0.finished && !$0.live
                    let rightResume = !$1.finished && !$1.live
                    return leftResume != rightResume ? leftResume : $0.updatedAt > $1.updatedAt
                }
            }
            var recovery: [ViewerWatchRecord] = []
            for index in 0..<Self.recoveryEntriesPerViewer {
                for queue in queues where index < queue.count { recovery.append(queue[index]) }
            }
            var backup = Data()
            while true {
                backup = try encoder.encode(Snapshot(records: recovery, incompleteRecovery: recovery.count < next.count))
                if backup.count <= Self.recoveryByteLimit { break }
                recovery.removeLast()
            }
            // Budget the app's persistent domain, not global/registration
            // defaults that belong to the OS and aren't stored by this app.
            var domain = defaultsDomainName.flatMap { defaults.persistentDomain(forName: $0) }
                ?? defaults.dictionaryRepresentation()
            domain[Self.recoveryKey] = backup
            let projected = try PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0)
            // Leave headroom below tvOS's 512 KB warning / 1 MB termination.
            guard projected.count < 384 * 1024 else { throw ViewerWatchStoreError.recoveryCapacity }
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Stage a removal's recovery snapshot before committing the primary
            // file. Defaults persistence is asynchronous: abrupt interruption
            // plus cache purge still cannot be guaranteed without durable sync.
            if removing { defaults.set(backup, forKey: Self.recoveryKey) }
            try full.write(to: fileURL, options: .atomic)
            if !removing { defaults.set(backup, forKey: Self.recoveryKey) }
            records = next
            recoveryIsLimited = recovery.count < next.count
            failure = nil
        } catch {
            let typed = (error as? ViewerWatchStoreError) ?? .writeFailed
            failure = typed
            throw typed
        }
    }
}
