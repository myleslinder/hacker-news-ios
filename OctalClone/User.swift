//
//  User.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-06.
//

import Foundation

protocol NeedsName {
    var created: Int { get }
    var karma: Int { get }
    var about: String? { get }
}

struct User: Decodable, Identifiable, Hashable, NeedsName {
    let username: String
    @HTMLText var about: String?
    let karma: Int
    let createdAt: Int
    var created: Int { createdAt } // NeedsName protocol conformance
    let avg: Double?
    let submitted: Int
    let updatedAt: String
    let submissionCount: Int
    let commentCount: Int
    let objectID: String
    var id: String { objectID }

    enum CodingKeys: String, CodingKey {
        case username
        case about
        case karma
        case createdAt = "created_at_i"
        case avg
        case submitted
        case updatedAt = "updated_at"
        case submissionCount = "submission_count"
        case commentCount = "comment_count"
        case objectID
    }
}

// MARK: - User/Activity Navigation

struct NavigableHNUser: Identifiable, Hashable, Codable {
    let id: String
    var type: NavigationType = .user

    enum NavigationType: Hashable, Codable, Equatable {
        case user
        case activity(Post.PostType = .story)
    }
}
