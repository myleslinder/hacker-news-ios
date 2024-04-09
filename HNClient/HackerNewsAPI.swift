//
//  HackerNewsAPI.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-16.
//

import Combine
import Foundation
import SwiftUI

extension HackerNewsAPI.StoryCategory {
    var color: Color {
        switch self {
        case .top: return .orange
        case .new: return .cyan
        case .best: return .indigo
        case .ask: return .mint
        case .show: return .teal
        }
    }
}



extension HackerNewsAPI {
    struct HackerNewsUser: Decodable, Identifiable, Equatable, NeedsName {
        let id: String
        let created: Int
        let karma: Int
        let about: String?
        let delay: Int?
    }
}


enum HackerNewsAPI {
    static func fetchUser(_ id: String) async -> Result<HackerNewsUser, UserFetchError> {
        do {
            let (data, response) = try await URLSession.shared.data(from: APIConstants.buildUserUrl(id: id))
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
                return Result.failure(UserFetchError.algolia(URLError(.badServerResponse).localizedDescription))
            }
            let user = try JSONDecoder().decode(HackerNewsUser.self, from: data)
            return Result.success(user)
        }
        catch let error as URLError {
            return Result.failure(UserFetchError.network(error.localizedDescription))
        }
        catch is DecodingError {
            return Result.failure(UserFetchError.app("Something went wrong"))
        }
        catch {
            return Result.failure(UserFetchError.hn(error.localizedDescription))
        }
    }

    static func fetchItemIds(for category: StoryCategory) async -> Result<[Int], Error> {
        do {
            let (data, response) = try await URLSession.shared.data(from: APIConstants.buildCategoryUrl(for: category))
            try response.check()
            let itemIds = try JSONDecoder().decode([Int].self, from: data)
            return Result.success(itemIds)
        } catch {
            return Result.failure(error)
        }
    }

    static func fetchPopulatedItem(id: Int) async throws -> PopulatedItem {
        let (data, response) = try await URLSession.shared.data(from: APIConstants.buildItemUrl(id: id))
        try response.check()
        let item = try JSONDecoder().decode(Item.self, from: data)

        return try await withThrowingTaskGroup(of: PopulatedItem.self, body: { taskGroup in
            for childId in item.childIds {
                taskGroup.addTask {
                    try await fetchPopulatedItem(id: childId)
                }
            }
            var children = [PopulatedItem]()
            for try await child in taskGroup {
                children.append(child)
            }
            return PopulatedItem(from: item, index: 0, children: children)
        })
    }

    static func fetchItem(_ id: Int, offset: Int = 0, session: URLSession) -> AnyPublisher<(offset: Int, item: Item), any Error> {
        session.dataTaskPublisher(for: APIConstants.buildItemUrl(id: id))
            .tryMap { (data, response) in
                try response.check()
                return data
            }
            .decode(type: Item.self, decoder: JSONDecoder())
            .map { (offset: 0, item: $0) }
            .eraseToAnyPublisher()
    }

    static func fetchCommentsWithMultipleChildren(id: Int, session: URLSession) -> AnyPublisher<[Item], any Error> {
        AlgoliaAPI.commentIdToChildCountPublisher(for: id)
            .flatMap { parentIdToCount in
                parentIdToCount.filter { $0.value > 1 }.keys.publisher
            }
            .flatMap { HackerNewsAPI.fetchItem($0, session: session) }
            .map(\.item)
            .collect()
            .eraseToAnyPublisher()
    }

    // MARK: - Enums

    enum StoryCategory: String, CaseIterable {
        case top
        case best
        case new
        case ask
        case show
    }

    enum StoryOrder: Equatable, Hashable {
        case original
        case search(AlgoliaSearchType)
    }

    // MARK: - Private

    private enum APIConstants {
        private static let baseUrl = "https://hacker-news.firebaseio.com/v0"
        static func buildItemUrl(id: Int) -> URL { URL(string: "\(baseUrl)/item/\(id).json")! }
        static func buildCategoryUrl(for category: StoryCategory) -> URL { URL(string: "\(baseUrl)/\(category.rawValue)stories.json")! }
        static func buildUserUrl(id: String) -> URL { URL(string: "\(baseUrl)/user/\(id).json")! }
    }
}

// MARK: - Extensions


extension URLResponse {
    // TODO: rename me and throw errors with better descriptions
    func check() throws {
        let httpResponse = self as! HTTPURLResponse
        guard (200...299).contains(httpResponse.statusCode)
        else {
            if (400...499).contains(httpResponse.statusCode) {
                throw UserFetchError.response("File not found.")
            }
            if (500...599).contains(httpResponse.statusCode) {
                throw UserFetchError.response("Bad Server Response")
            }
            throw UserFetchError.response("Something went wrong")
        }
    }
}

extension HackerNewsAPI.StoryOrder {
    static var allCases: [HackerNewsAPI.StoryOrder] {
        [.original, .search(.best), .search(.recent)]
    }

    var label: String {
        switch self {
        case .original: return "Original"
        case .search(let type): return type.rawValue
        }
    }

    var systemImage: String {
        switch self {
        case .original: return "hand.thumbsup.circle.fill"
        case .search(let type): return type.systemImage
        }
    }
}

extension HackerNewsAPI.StoryCategory: CustomStringConvertible {
    var description: String { label }

    var label: String {
        switch self {
        case .top: return "Top Stories"
        case .new: return "New Stories"
        case .best: return "Best Stories"
        case .ask: return "Ask HN"
        case .show: return "Show HN"
        }
    }

    var systemImage: String {
        switch self {
        case .top: return "arrow.up.circle.fill"
        case .new: return "calendar.circle.fill"
        case .best: return "star.circle.fill"
        case .ask: return "hand.raised.circle.fill"
        case .show: return "music.mic.circle.fill"
        }
    }
}

extension HackerNewsAPI {
    // TODO: the post type means jobs and so on wont be supported
    struct Item: Decodable, Identifiable, Equatable {
        let id: Int
        let author: String?
        let commentCount: Int?
        let _childIds: [Int]?
        var childIds: [Int] { _childIds ?? [] }
        let points: Int?
        let time: Int?
        let title: String? // HTML
        let text: String? // HTML
        let type: Post.PostType?
        let url: String?
        let isDeleted: Bool?
        let isDead: Bool?

        enum CodingKeys: String, CodingKey {
            case author = "by"
            case commentCount = "descendants"
            case id
            case _childIds = "kids"
            case points = "score"
            case time
            case title
            case text
            case type
            case url
            case isDeleted = "deleted"
            case isDead = "dead"
        }
    }

    struct PopulatedItem: Identifiable {
        let id: Int
        let author: String?
        let commentCount: Int?
        let points: Int?
        let time: Int?
        let title: String? // HTML
        let text: String?
        let type: Post.PostType?
        let url: String?
        let isDeleted: Bool?
        let isDead: Bool?
        var children: [PopulatedItem]
        let index: Int

        init(from item: Item, index: Int, children: [PopulatedItem]) {
            self.id = item.id
            self.author = item.author
            self.commentCount = item.commentCount
            self.points = item.points
            self.time = item.time
            self.title = item.title
            self.type = item.type
            self.url = item.url
            self.isDeleted = item.isDeleted
            self.isDead = item.isDead
            self.text = item.text
            self.index = index
            self.children = children
        }
    }
}
