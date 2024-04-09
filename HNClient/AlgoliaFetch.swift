//
//  AlgoliaFetch.swift
//  Mess Around
//
//  Created by Myles Linder on 2023-07-26.
//

import Combine
import Foundation

typealias AlgoliaSearchType = AlgoliaAPI.Endpoint.SearchParam.SearchType
typealias AlgoliaSearchParam = AlgoliaAPI.Endpoint.SearchParam

func buildCommentTree(_ id: Int, comments: [CommentSearchResult]) -> [CommentPost] {
    comments
        .filter { $0.parentId == id }
        .map{ CommentPost(from: $0, children: buildCommentTree($0.id, comments:  comments)) }
}

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
    
    // MARK: Methods
    
    static func userPublisher(id: String)  -> AnyPublisher<User, any Error>{
        URLSession.shared.dataTaskPublisher(for: AlgoliaAPI.buildUrl(.users(id: id)))
            .map(\.data)
            .decode(type: User.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    static func searchResultsPublisher(_ query: AlgoliaAPI.Endpoint.SearchParam) -> AnyPublisher<[SearchResult], any Error> {
        URLSession.shared.dataTaskPublisher(for: AlgoliaAPI.buildUrl(.search(query)))
            .map(\.data)
            .decode(type: SearchResultCollection.self, decoder: JSONDecoder())
            .map(\.hits)
            .eraseToAnyPublisher()
    }

    static func postPublisher(_ id: Int) -> AnyPublisher<PostVariant, any Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        return URLSession.shared.dataTaskPublisher(for: AlgoliaAPI.buildUrl(.items(id: String(id))))
    //        .map(\.data)
            .map {
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("post pub pre decode for", id, timeElapsed)
                return $0.data
            }
            .decode(type: Post.self, decoder: JSONDecoder())
            .map {
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("post pub for id", id, timeElapsed)
                switch $0 {
                case .comment(let c): return c
                case .story(let c): return c
                }
            }
            .eraseToAnyPublisher()
    }
    
    static func commentTreePublisher(for id: Int) -> AnyPublisher<[CommentPost], any Error> {
        print("HERE")
        return AlgoliaAPI.searchResultsPublisher(.init(tagGroups: [.and([.comment, .story_(id: String(id))])]))
            .map { hits in
                print("HERE NEXT")
                return hits.compactMap {
                    switch $0 {
                    case .comment(let c): return c
                    default: return nil
                    }
                }
            }
            .map({ comments in
                print("HERE NEXT NEXT")
                return comments.map{
                    CommentPost(from: $0, children: buildCommentTree($0.id, comments:  comments))
                }
            })
            .eraseToAnyPublisher()
    }
    
    static func commentIdToChildCountPublisher(for id: Int) -> AnyPublisher<[Int: Int], any Error> {
        let startTime = CFAbsoluteTimeGetCurrent()
        return AlgoliaAPI.searchResultsPublisher(.init(tagGroups: [.and([.comment, .story_(id: String(id))])]))
            .map { hits in
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("searching:", timeElapsed)
                return hits.compactMap {
                    switch $0 {
                    case .comment(let c): return c
                    default: return nil
                    }
                }.reduce([Int: Int]()) { dict, result in
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

            init(searchType: SearchType = .recent, query: String? = nil, tag: Tag, numericFilter: [NumericFilter]? = .none) {
                self.searchType = searchType
                self.query = query
                self.tagGroups = [.and([tag])]
                self.numericFilter = numericFilter
            }
            
            var path: String { searchType == .best ? "search" : "search_by_date" }
            var queryItems: [URLQueryItem] {
                return [
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "tags", value: buildTagQueryParam(tagGroups)),
                    URLQueryItem(name: "numericFilters", value: buildNumericFilterParam(numericFilter)),
                    // TODO: can go up to 1000 and then no need for pagination
                    // but probably a bad loading experience in cases of "best"
                    // also need some pagination for history page
                    URLQueryItem(name: "hitsPerPage", value: "500"),
                ].filter { !($0.value?.isEmpty ?? true) }
            }

            enum SearchType: String, CaseIterable, Hashable, RawRepresentable {
                case recent = "Recent"
                case best = "Best"
                
                var systemImage: String {
                    switch self {
                    case .recent: return "calendar.circle.fill"
                    case .best: return "medal.fill"
                    }
                }
            }
            
            enum NumericFilter {
                
                case createdAt(Operator, Int)  // created_at_i
                case points(Operator, Int)
                case numComments(Operator, Int) // num_comments
                
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
                
                static subscript(_ item: Self) -> Int {
                    pageTypeCases.firstIndex(of: item) ?? 0
                }
                
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
        static let scheme = "http"
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
    private func tagsToParamString(_ tags: [AlgoliaSearchParam.Tag]) -> String? {
        if tags.isEmpty { return nil }
        return tags
            .map(\.description)
            .joined(separator: ",")
    }
    
    private func buildNumericFilterParam(_ filters: [NumericFilter]?) -> String {
        filters?.map(\.description)
            .joined(separator: ",") ?? ""
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

extension AlgoliaAPI.Endpoint.SearchParam.Tag {
    var isContentType: Bool {
        switch self {
        case .story: return true
        case .comment: return true
        default: return false
        }
    }
    
    var isPageType: Bool {
        switch self {
        case .show_hn: return true
        case .ask_hn: return true
        default: return false
        }
    }
    
    var isIdType: Bool {
        switch self {
        case .author_: return true
        case .story_: return true
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
        case .front_page: return "arrow.up.circle.fill"
        case .ask_hn: return "questionmark.circle.fill"
        case .show_hn: return "hand.raised.circle.fill"
        case .story: return "doc.circle.fill"
        case .comment: return "message.circle.fill"
        default: return "space"
        }
    }
}
