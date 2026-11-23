//
//  ViewerProfilesManager.swift
//  Yattee
//
//  Persists small viewer identities and selection without changing shared data.
//

import Foundation
import Observation

extension Notification.Name {
    static let viewerDidChange = Notification.Name("yatteeProfiles.viewerDidChange")
}

enum ViewerProfileError: Error, LocalizedError, Equatable, Sendable {
    case invalidName
    case duplicateName
    case missingViewer
    case unavailableStorage

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return String(localized: "viewers.error.name")
        case .duplicateName:
            return String(localized: "viewers.error.duplicate")
        case .missingViewer:
            return String(localized: "viewers.error.missing")
        case .unavailableStorage:
            return String(localized: "viewers.error.storage")
        }
    }
}

@MainActor
@Observable
final class ViewerProfilesManager {
    // One record avoids a profile-list/active-ID mismatch after a partial update.
    // This is deliberately outside SwiftData's purgeable tvOS cache and outside
    // all server-account, credential and cloud-sync namespaces.
    static let storageKey = "yatteeProfiles.localViewers.v1"

    private struct Snapshot: Codable {
        var version: Int = 1
        var profiles: [ViewerProfile]
        var activeViewerID: UUID?
    }

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var profiles: [ViewerProfile]
    private(set) var activeViewerID: UUID
    private(set) var storageUnavailable = false
    /// Called once per real switch, after the new selection is saved and before
    /// `viewerDidChange` is posted, so the old viewer's playback can be closed
    /// before any screen reloads for the new viewer.
    @ObservationIgnored var onViewerSwitch: (@MainActor (_ from: UUID, _ to: UUID) -> Void)?

    var activeViewer: ViewerProfile {
        profiles.first { $0.id == activeViewerID } ?? profiles[0]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initial = ViewerProfile(id: UUID(), name: String(localized: "viewers.default"))
        profiles = [initial]
        activeViewerID = initial.id

        guard defaults.object(forKey: Self.storageKey) != nil else {
            do { try commit(profiles: profiles, activeID: activeViewerID) }
            catch { storageUnavailable = true }
            return
        }

        guard let data = defaults.data(forKey: Self.storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.version == 1,
              !snapshot.profiles.isEmpty,
              Set(snapshot.profiles.map(\.id)).count == snapshot.profiles.count,
              snapshot.profiles.allSatisfy({ !Self.normalizedName($0.name).isEmpty }) else {
            // Preserve unreadable/newer bytes. Never replace somebody's saved
            // profiles with our temporary fallback on launch or on a later edit.
            storageUnavailable = true
            return
        }
        profiles = snapshot.profiles
        activeViewerID = snapshot.activeViewerID.flatMap { id in
            profiles.contains { $0.id == id } ? id : nil
        } ?? profiles[0].id
        if snapshot.activeViewerID != activeViewerID {
            do { try commit(profiles: profiles, activeID: activeViewerID) }
            catch { storageUnavailable = true }
        }
    }

    @discardableResult
    func add(name: String) throws -> ViewerProfile {
        let name = try validatedName(name)
        let profile = ViewerProfile(id: UUID(), name: name)
        // Adding a viewer does not silently switch away from the current one.
        try commit(profiles: profiles + [profile], activeID: activeViewerID)
        return profile
    }

    func rename(id: UUID, name: String) throws {
        guard profiles.contains(where: { $0.id == id }) else { throw ViewerProfileError.missingViewer }
        let name = try validatedName(name, excluding: id)
        try commit(
            profiles: profiles.map { $0.id == id ? ViewerProfile(id: id, name: name) : $0 },
            activeID: activeViewerID
        )
    }

    func select(id: UUID) throws {
        guard profiles.contains(where: { $0.id == id }) else { throw ViewerProfileError.missingViewer }
        let previous = activeViewerID
        try commit(profiles: profiles, activeID: id)
        if previous != id { onViewerSwitch?(previous, id) }
        NotificationCenter.default.post(name: .viewerDidChange, object: nil)
        NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validatedName(_ name: String, excluding id: UUID? = nil) throws -> String {
        let name = Self.normalizedName(name)
        guard !name.isEmpty, name.count <= 40 else { throw ViewerProfileError.invalidName }
        guard !profiles.contains(where: {
            $0.id != id && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else { throw ViewerProfileError.duplicateName }
        return name
    }

    private func commit(profiles: [ViewerProfile], activeID: UUID) throws {
        guard !storageUnavailable else { throw ViewerProfileError.unavailableStorage }
        let data: Data
        do {
            data = try JSONEncoder().encode(Snapshot(profiles: profiles, activeViewerID: activeID))
        } catch {
            throw ViewerProfileError.unavailableStorage
        }
        defaults.set(data, forKey: Self.storageKey)
        self.profiles = profiles
        activeViewerID = activeID
    }
}
