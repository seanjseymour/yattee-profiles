//
//  ViewerProfilesTests.swift
//  YatteeTests
//
//  Local viewer persistence, validation and preservation of existing defaults.
//

import Foundation
import Testing
@testable import Yattee

@MainActor
@Suite("Local viewer profiles")
struct ViewerProfilesTests {
    private func withDefaults(_ test: (UserDefaults) throws -> Void) throws {
        let suite = "ViewerProfilesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    @Test("Upgrade adds one stable viewer without changing existing defaults")
    func upgradePreservesSharedState() throws {
        try withDefaults { defaults in
            defaults.set(Data([1, 2, 3]), forKey: "configuredInstances")
            defaults.set("existing-server", forKey: "activeInstanceID")
            defaults.set("existing-account", forKey: "selectedDataContext")
            defaults.set(false, forKey: "saveWatchHistory")
            let before = defaults.dictionaryRepresentation()
            let manager = ViewerProfilesManager(defaults: defaults)
            let reloaded = ViewerProfilesManager(defaults: defaults)
            #expect(manager.profiles.count == 1)
            #expect(reloaded.profiles == manager.profiles)
            #expect(reloaded.activeViewerID == manager.activeViewerID)
            let added = try manager.add(name: "Second")
            try manager.select(id: added.id)
            try manager.rename(id: added.id, name: "Renamed")
            for (key, value) in before {
                #expect(NSDictionary(dictionary: [key: value]).isEqual(to: [key: defaults.object(forKey: key)!]))
            }
        }
    }

    @Test("Add and rename retain IDs; selection survives reconstruction")
    func relaunch() throws {
        try withDefaults { defaults in
            let manager = ViewerProfilesManager(defaults: defaults)
            let original = manager.activeViewerID
            let second = try manager.add(name: "  Sean  ")
            #expect(second.name == "Sean")
            #expect(manager.activeViewerID == original)
            try manager.select(id: second.id)
            try manager.rename(id: second.id, name: "Sean TV")
            let reloaded = ViewerProfilesManager(defaults: defaults)
            #expect(reloaded.profiles == manager.profiles)
            #expect(reloaded.activeViewerID == second.id)
            #expect(reloaded.activeViewer.name == "Sean TV")
        }
    }

    @Test("Invalid names and unknown selection do not mutate the saved record")
    func rejectsInvalidEdits() throws {
        try withDefaults { defaults in
            let manager = ViewerProfilesManager(defaults: defaults)
            let second = try manager.add(name: "Sean")
            let before = defaults.data(forKey: ViewerProfilesManager.storageKey)
            #expect(throws: ViewerProfileError.invalidName) { try manager.add(name: " \n ") }
            #expect(throws: ViewerProfileError.invalidName) { try manager.add(name: String(repeating: "a", count: 41)) }
            #expect(throws: ViewerProfileError.duplicateName) { try manager.add(name: "sean") }
            #expect(throws: ViewerProfileError.duplicateName) {
                try manager.rename(id: second.id, name: manager.profiles[0].name)
            }
            #expect(throws: ViewerProfileError.missingViewer) { try manager.select(id: UUID()) }
            #expect(defaults.data(forKey: ViewerProfilesManager.storageKey) == before)
        }
    }

    @Test("Missing and dangling active IDs recover the first saved viewer")
    func repairsSelection() throws {
        for activeID in [nil, UUID().uuidString] as [String?] {
            try withDefaults { defaults in
                let id = UUID()
                var record: [String: Any] = ["version": 1, "profiles": [["id": id.uuidString, "name": "Saved viewer"]]]
                record["activeViewerID"] = activeID
                defaults.set(try JSONSerialization.data(withJSONObject: record), forKey: ViewerProfilesManager.storageKey)
                let manager = ViewerProfilesManager(defaults: defaults)
                #expect(!manager.storageUnavailable)
                #expect(manager.activeViewerID == id)
                #expect(manager.profiles.count == 1)
                #expect(ViewerProfilesManager(defaults: defaults).activeViewerID == id)
            }
        }
    }

    @Test("Corrupt, empty, duplicate-ID and future records are preserved")
    func preservesUnreadableRecords() throws {
        let id = UUID().uuidString
        let records = [
            "not JSON",
            "{\"version\":2,\"profiles\":[]}",
            "{\"version\":1,\"profiles\":[]}",
            "{\"version\":1,\"profiles\":[{\"id\":\"\(id)\",\"name\":\"A\"},{\"id\":\"\(id)\",\"name\":\"B\"}]}"
        ]
        for record in records {
            try withDefaults { defaults in
                let bytes = Data(record.utf8)
                defaults.set(bytes, forKey: ViewerProfilesManager.storageKey)
                let manager = ViewerProfilesManager(defaults: defaults)
                #expect(manager.storageUnavailable)
                #expect(throws: ViewerProfileError.unavailableStorage) { try manager.add(name: "New") }
                #expect(throws: ViewerProfileError.unavailableStorage) { try manager.select(id: manager.activeViewerID) }
                #expect(defaults.data(forKey: ViewerProfilesManager.storageKey) == bytes)
            }
        }
    }

    @Test("Non-data record remains untouched")
    func preservesWrongType() throws {
        try withDefaults { defaults in
            defaults.set("preserve me", forKey: ViewerProfilesManager.storageKey)
            let manager = ViewerProfilesManager(defaults: defaults)
            #expect(manager.storageUnavailable)
            #expect(defaults.string(forKey: ViewerProfilesManager.storageKey) == "preserve me")
        }
    }

    private final class EventLog: @unchecked Sendable { var events: [String] = [] }

    @Test("A real switch reports old and new viewer once, before viewerDidChange")
    func switchHookRunsBeforeNotification() throws {
        try withDefaults { defaults in
            let manager = ViewerProfilesManager(defaults: defaults)
            let a = manager.activeViewerID
            let b = try manager.add(name: "B").id
            let log = EventLog()
            manager.onViewerSwitch = { from, to in
                log.events.append("switch \(from == a ? "A" : "?")->\(to == b ? "B" : "?")")
            }
            let token = NotificationCenter.default.addObserver(forName: .viewerDidChange, object: nil, queue: nil) { _ in
                log.events.append("viewerDidChange")
            }
            defer { NotificationCenter.default.removeObserver(token) }

            try manager.select(id: b)
            #expect(log.events == ["switch A->B", "viewerDidChange"])

            // Re-selecting the active viewer and a refused selection are not switches.
            log.events.removeAll()
            try manager.select(id: b)
            #expect(throws: ViewerProfileError.missingViewer) { try manager.select(id: UUID()) }
            #expect(!log.events.contains { $0.hasPrefix("switch") })
        }
    }
}
