//
//  ViewerProfile.swift
//  Yattee
//
//  An app-local viewer identity, independent of server accounts and content.
//

import Foundation

struct ViewerProfile: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
}
