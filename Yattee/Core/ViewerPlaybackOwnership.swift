//
//  ViewerPlaybackOwnership.swift
//  Yattee
//
//  Opening captures a viewer; reloads and automatic queue playback keep it.
//

import Foundation

struct ViewerPlaybackOwnership: Sendable {
    struct Session: Equatable, Sendable {
        let id: UUID
        let viewerID: UUID
    }
    private(set) var session: Session?

    mutating func open(viewerID: UUID?) {
        session = viewerID.map { Session(id: UUID(), viewerID: $0) }
    }

    mutating func load(viewerID: UUID?) {
        if session == nil { open(viewerID: viewerID) }
    }

    mutating func close() { session = nil }
}
