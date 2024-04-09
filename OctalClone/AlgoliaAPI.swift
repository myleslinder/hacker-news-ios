//
//  AlgoliaFetch.swift
//  HNClient
//
//  Created by Myles Linder on 2023-07-26.
//

import Combine
import Foundation

typealias AlgoliaSearchType = AlgoliaAPI.Endpoint.SearchParam.SearchType
typealias AlgoliaSearchParam = AlgoliaAPI.Endpoint.SearchParam

enum AlgoliaAPI {
    static var baseComponents: URLComponents { APIConstants.baseComponents }
    
    static func buildUrl(_ endpoint: Endpoint) -> URL {
        var components = APIConstants.baseComponents
        switch endpoint {
        case .items(let id): components.path += "items/\(id)"
        case .users(let id): components.path += "users/\(id)"
        case .search(let searchParam):
            components.path += searchParam.path
            components.queryItems = searchParam.queryItems
        }
        return components.url!
    }
    
    // MARK: User & Search Async
    
    static func user(id: String) async -> Result<User, UserFetchError> {
        do {
            let (data, response) = try await URLSession.shared.data(from: AlgoliaAPI.buildUrl(.users(id: id)))
            try response.check()
            let user = try JSONDecoder().decode(User.self, from: data)
            return Result.success(user)
        }
        catch let error as UserFetchError {
            return Result.failure(error)
        }
        catch let error as URLError {
            return Result.failure(UserFetchError.network(error.localizedDescription))
        }
        catch is DecodingError {
            return Result.failure(UserFetchError.app("Something went wrong"))
        }
        catch {
            return Result.failure(UserFetchError.algolia(error.localizedDescription))
        }
    }
    
    static func search(_ query: AlgoliaAPI.Endpoint.SearchParam) async throws -> [SearchResult] {
        let (data, _) = try await URLSession.shared.data(from: AlgoliaAPI.buildUrl(.search(query)))
        let results = try JSONDecoder().decode(SearchResultCollection.self, from: data)
        return results.hits
    }
    
    // MARK: Publishers
    
    private static func requestPublisher(_ endpoint: Endpoint) -> AnyPublisher<Data, URLError> {
        URLSession.shared.dataTaskPublisher(for: AlgoliaAPI.buildUrl(endpoint))
            .map(\.data)
            .eraseToAnyPublisher()
    }
    
    static func postPublisher(_ id: Int) -> AnyPublisher<PostVariant, any Error> {
        AlgoliaAPI.requestPublisher(.items(id: String(id)))
            .decode(type: Post.self, decoder: JSONDecoder())
            .map {
                switch $0 {
                case .comment(let c): return c
                case .story(let c): return c
                }
            }
            .eraseToAnyPublisher()
    }
    
    static func commentIdToChildCountPublisher(for id: Int) -> AnyPublisher<[Int: Int], any Error> {
        AlgoliaAPI.requestPublisher(.search(.init(tags: [.comment, .story_(id: String(id))])))
            .decode(type: SearchResultCollection.self, decoder: JSONDecoder())
            .map(\.hits)
            .map { hits in
                hits.onlyComments()
                    .reduce([Int: Int]()) { dict, result in
                        // TODO: dict as inout?
                        var d = dict
                        if let parentId = result.parentId, parentId != id {
                            d[parentId] = (d[parentId] ?? 0) + 1
                        }
                        return d
                    }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Endpoint

    enum Endpoint {
        case items(id: String)
        case users(id: String)
        case search(SearchParam)
    
        struct SearchParam {
            private let searchType: SearchType
            private let query: String?
            private let tagGroups: [TagGroup]?
            private let numericFilter: [NumericFilter]?
            
            init(searchType: SearchType = .recent, query: String? = nil, tagGroups: [TagGroup]? = .none, numericFilter: [NumericFilter]? = .none) {
                self.searchType = searchType
                self.query = query
                self.tagGroups = tagGroups
                self.numericFilter = numericFilter
            }

            init(searchType: SearchType = .recent, query: String? = nil, tags: [Tag], numericFilter: [NumericFilter]? = .none) {
                self.searchType = searchType
                self.query = query
                self.tagGroups = [.and(tags)]
                self.numericFilter = numericFilter
            }
            
            var path: String { searchType == .best ? "search" : "search_by_date" }
            var queryItems: [URLQueryItem] {
                [
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "tags", value: buildTagQueryParam(tagGroups)),
                    URLQueryItem(name: "numericFilters", value: buildNumericFilterParam(numericFilter)),
                    URLQueryItem(name: "hitsPerPage", value: "500"),
                ]
                .filter { !($0.value?.isEmpty ?? true) }
            }

            enum SearchType: String, CaseIterable, Hashable, RawRepresentable, ChangeMe {
                case recent = "Recent"
                case best = "Best"
                
                static func fromHNSortOrder(_ order: HackerNewsAPI.StoryOrder) -> Self {
                    switch order {
                    case .original: return .recent
                    case .search(let type): return type
                    }
                }
                
                var label: String {
                    rawValue
                }
                
                var systemImage: String {
                    switch self {
                    case .recent: return "calendar.circle.fill"
                    case .best: return "trophy.circle.fill"
                    }
                }
            }
            
            enum NumericFilter {
                case createdAt(Operator, Int)
                case points(Operator, Int)
                case numComments(Operator, Int)
                
                var description: String {
                    switch self {
                    case .createdAt(let op, let value): return "created_at_i\(op.label)\(value)"
                    case .points(let op, let value): return "points\(op.label)\(value)"
                    case .numComments(let op, let value): return "num_comments\(op.label)\(value)"
                    }
                }
                
                enum Operator {
                    case equal
                    case lessThan(equal: Bool = false)
                    case greaterThan(equal: Bool = false)
                    
                    var label: String {
                        switch self {
                        case .equal: return "="
                        case .greaterThan(let equal): return ">\(equal ? "=" : "")"
                        case .lessThan(let equal): return "<\(equal ? "=" : "")"
                        }
                    }
                }
            }

            // MARK: - Tag Groups

            enum TagGroup: Hashable {
                case and([Tag])
                case or([Tag])
            }

            enum Tag: Hashable, Identifiable {
                case story
                case comment
                case poll
                case pollopt
                case show_hn
                case ask_hn
                case front_page
                case author_(username: String)
                case story_(id: String)

                static var pageTypeCases: [AlgoliaAPI.Endpoint.SearchParam.Tag] {
                    [.show_hn, .ask_hn]
                }

                static var contentTypeCases: [AlgoliaAPI.Endpoint.SearchParam.Tag] {
                    [.story, .comment]
                }
                
                var id: String {
                    switch self {
                    case .story: return "story"
                    case .comment: return "comment"
                    case .poll: return "poll"
                    case .pollopt: return "pollopt"
                    case .show_hn: return "show_hn"
                    case .ask_hn: return "ask_hn"
                    case .front_page: return "front_page"
                    case .author_(let username): return "author_\(username)"
                    case .story_(let id): return "story_\(id)"
                    }
                }
            }
        }
    }

    // MARK: - Constants
    
    private enum APIConstants {
        static let scheme = "https"
        static let host = "hn.algolia.com"
        static let basePath = "/api/v1/"
        
        static var baseComponents: URLComponents {
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.path = basePath
            return components
        }
    }
    
    enum FetchStatus: Equatable {
        case idle
        case fetching
        case failed(reason: String)
    }
}

// MARK: - Extensions

extension AlgoliaAPI.Endpoint.SearchParam {
    private func buildNumericFilterParam(_ filters: [NumericFilter]?) -> String {
        filters?.map(\.description)
            .joined(separator: ",") ?? ""
    }
    
    private func tagsToParamString(_ tags: [AlgoliaSearchParam.Tag]) -> String? {
        guard !tags.isEmpty else { return nil }
        return tags
            .map(\.description)
            .joined(separator: ",")
    }
    
    private func buildTagQueryParam(_ tagGroups: [TagGroup]?) -> String {
        return tagGroups?.compactMap { tagGroup in
            switch tagGroup {
            case .and(let tags):
                return tagsToParamString(tags)
            case .or(let tags):
                if let orString = tagsToParamString(tags) {
                    return "(\(orString))"
                }
                return nil
            }
        }
        .joined(separator: ",") ?? ""
    }
}

//
// extension AlgoliaSearchParam: Equatable {
//    static func == (lhs: AlgoliaAPI.Endpoint.SearchParam, rhs: AlgoliaAPI.Endpoint.SearchParam) -> Bool {
//        lhs.numericFilter ==  rhs.numericFilter && lhs.
//    }
//
//
// }

extension AlgoliaAPI.Endpoint.SearchParam.Tag: CustomStringConvertible {
    var description: String {
        switch self {
        case .story: return "story"
        case .comment: return "comment"
        case .poll: return "poll"
        case .pollopt: return "pollopt"
        case .show_hn: return "show_hn"
        case .ask_hn: return "ask_hn"
        case .front_page: return "front_page"
        case .author_(let username): return "author_\(username)"
        case .story_(let id): return "story_\(id)"
        }
    }
}

extension AlgoliaAPI.Endpoint.SearchParam.Tag: ChangeMe {
    var isContentType: Bool {
        switch self {
        case .story, .comment: return true
        default: return false
        }
    }
    
    var isPageType: Bool {
        switch self {
        case .show_hn, .ask_hn: return true
        default: return false
        }
    }
    
    var isIdType: Bool {
        switch self {
        case .author_, .story_: return true
        default: return false
        }
    }
    
    var label: String {
        switch self {
        case .story: return "Stories"
        case .comment: return "Comments"
        case .poll: return "Poll"
        case .pollopt: return "Poll Option"
        case .show_hn: return "Show HN"
        case .ask_hn: return "Ask HN"
        case .front_page: return "Front Page"
        case .author_(let username): return "Author: \(username)"
        case .story_(let id): return "Story: \(id)"
        }
    }
    
    var systemImage: String {
        switch self {
        case .front_page: return HackerNewsAPI.StoryCategory.top.systemImage
        case .ask_hn: return HackerNewsAPI.StoryCategory.ask.systemImage
        case .show_hn: return HackerNewsAPI.StoryCategory.show.systemImage
        case .story: return "doc.badge.ellipsis"
        case .comment: return "message.circle.fill"
        default: return "space"
        }
    }
}
