//
//  HNApiPub.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-23.
//

import Foundation
import Combine

enum HackerNewsAPIPub {
    
    static func fetchCategoryItemIds(for category: StoryCategory) -> some Publisher<[Int], any Error> {
        URLSession.shared.dataTaskPublisher(for: APIConstants.buildCategoryUrl(for: category))
            .map(\.data)
            .decode(type: [Int].self, decoder: JSONDecoder())
    }
    
    static func q(_ id: Int, session: URLSession) -> AnyPublisher<Data, URLSession.DataTaskPublisher.Failure> {
        let s = session.dataTaskPublisher(for: APIConstants.buildItemUrl(id: id))
        if let urlCache = session.configuration.urlCache, let cachedResponse = urlCache.cachedResponse(for: s.request) {
            print("cache hit!")
            urlCache.removeCachedResponse(for: s.request)
            return Just(cachedResponse.data)
                .setFailureType(to: URLSession.DataTaskPublisher.Failure.self)
                .eraseToAnyPublisher()
        } else {
            return s
                .map(\.data)
                .eraseToAnyPublisher()
        }
    }
    
    static func fetchItem(_ id: Int, offset: Int = 0, session: URLSession) -> AnyPublisher<(offset: Int, item: Item), any Error> {
        q(id, session: session)
            .decode(type: Item.self, decoder: JSONDecoder())
            .map { (offset: 0, item: $0) }
            .eraseToAnyPublisher()
    }
  
    static func fetchCommentsWithMultipleChildren(id: Int, session: URLSession) -> AnyPublisher<[Item], any Error> {
        AlgoliaAPI.commentIdToChildCountPublisher(for: id)
            .flatMap { parentIdToCount in
                parentIdToCount.filter { $0.value > 1 }.keys.publisher
            }
            .flatMap { HackerNewsAPIPub.fetchItem($0, session: session) }
            .map(\.item)
            .collect()
            .eraseToAnyPublisher()
    }
    
//
//    static func fetchPopulatedItem(_ id: Int, forIndex: Int = 0, session: URLSession) -> AnyPublisher<HackerNewsAPIPub.PopulatedItem, any Error> {
//        HackerNewsAPIPub.fetchItem(id, offset: forIndex, session: session)
//            .flatMap { _, item in
//                item.childIds.enumerated()
//                    .publisher
//                    .flatMap { fetchPopulatedItem($0.element, forIndex: $0.offset, session: session) }
//                    .collect()
//                    .map { children in
//                        HackerNewsAPIPub.PopulatedItem(from: item, index: forIndex, children: children.sorted(\.index, <))
//                    }
//            }
//            .eraseToAnyPublisher()
//    }
    
    // MARK: - Enums

    enum StoryCategory: String {
        case new
        case top
        case best
        case ask
        case show
    }
    
    enum StoryOrder: Equatable, Hashable {
        case original
        case search(AlgoliaSearchType)
    }
    
    // MARK: - Private
    
    private static func handleURLResponse<Data>(_ input: (data: Data, response: URLResponse)) throws -> Data {
        guard let httpResponse = input.response as? HTTPURLResponse, httpResponse.statusCode == 200
        else { throw URLError(.badServerResponse) }
        return input.data
    }

    private enum APIConstants {
        private static let baseUrl = "https://hacker-news.firebaseio.com/v0"
        static func buildItemUrl(id: Int) -> URL { URL(string: "\(baseUrl)/item/\(id).json")! }
        static func buildCategoryUrl(for category: StoryCategory) -> URL { URL(string: "\(baseUrl)/\(category.rawValue)stories.json")! }
    }
}

// MARK: - Extensions

extension HackerNewsAPIPub.StoryOrder: CaseIterable {
    static var allCases: [HackerNewsAPIPub.StoryOrder] {
        [.original, .search(.best), .search(.recent)]
    }

}

extension HackerNewsAPIPub.StoryOrder {
    var label: String {
        switch self {
        case .original: return "Original"
        case .search(let type): return type.rawValue
        }
    }
    
    var systemImage: String {
        switch self {
        case .original: return "space"
        case .search(let type): return type.systemImage
        }
    }
}


extension HackerNewsAPIPub.StoryCategory: CustomStringConvertible {
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
        case .top: return "arrow.up"
        case .new: return "calendar.badge.exclamationmark"
        case .best: return "star"
        case .ask: return "hand.raised"
        case .show: return "eye"
        }
    }
}

extension HackerNewsAPIPub {
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
  
//    struct PopulatedItem: Identifiable {
//        let id: Int
//        let author: String?
//        let commentCount: Int?
//        let points: Int?
//        let time: Int?
//        let title: String? // HTML
//        let text: String?
//        let type: Post.PostType?
//        let url: String?
//        let isDeleted: Bool?
//        let isDead: Bool?
//        var children: [PopulatedItem]
//        let index: Int
//
//        init(from item: Item, index: Int, children: [PopulatedItem]) {
//            self.id = item.id
//            self.author = item.author
//            self.commentCount = item.commentCount
//            self.points = item.points
//            self.time = item.time
//            self.title = item.title
//            self.type = item.type
//            self.url = item.url
//            self.isDeleted = item.isDeleted
//            self.isDead = item.isDead
//            self.text = item.text
//            self.index = index
//            self.children = children
//        }
//    }
}
