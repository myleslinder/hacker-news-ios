//
//  SearchResults.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-06.
//

import Foundation

struct SearchResultCollection: Decodable {
    private let _hits: [SearchResult]?
    var hits: [SearchResult] { _hits ?? [] }
    let page: Int
    let nbHits: Int
    let nbPages: Int
    let hitsPerPage: Int
    
    enum CodingKeys: String, CodingKey {
        case _hits = "hits"
        case page
        case nbHits
        case nbPages
        case hitsPerPage
    }
   
}

extension Array where Element == SearchResult {
    func onlyStories() -> [StorySearchResult] {
        compactMap { result in
            switch result {
            case .story(let story): return story
            default: return nil
            }
        }
    }
    func onlyComments() -> [CommentSearchResult] {
        compactMap { result in
            switch result {
            case .comment(let comment): return comment
            default: return nil
            }
        }
    }
}

enum SearchResult: Decodable, Hashable, Identifiable, Equatable {
    case story(StorySearchResult)
    case comment(CommentSearchResult)

    var id: Int {
        switch self {
        case .comment(let comment): return comment.id
        case .story(let story): return story.id
        }
    }
    
    var variant: any SearchResultVariant {
        switch self {
        case .comment(let c): return c
        case .story(let s): return s
        }
    }

    var type: Post.PostType {
        switch self {
        case .comment: return .comment
        case .story: return .story
        }
    }
}

extension SearchResult {
    private struct InvalidTypeError: Error {
        var type: String
        //           ...
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tags = try container.decode([String].self, forKey: ._tags)

        var resultType: String
        if tags.contains("story") {
            resultType = "story"
        } else {
            resultType = "comment"
        }

        switch resultType {
        case "story":
            self = try .story(StorySearchResult(from: decoder))
        case "comment":
            self = try .comment(CommentSearchResult(from: decoder))
        default:
            throw InvalidTypeError(type: resultType)
        }
    }

    private enum CodingKeys: CodingKey {
        case _tags
    }
}

// MARK: - Search Result Variants

protocol SearchResultVariant: Decodable, Identifiable, Hashable, Equatable {
    var objectID: String { get }
    var linkedUrlString: String? { get }
    var postUrlString: String { get }
    var author: String { get }
    var storyText: String? { get }
    var text: String? { get }
    var title: String { get }
    var relevancyScore: Int? { get }
    var createdAt: Int { get }
    // add highlight result
}

// MARK: - Stories

struct StorySearchResult: SearchResultVariant {
    let objectID: String
    let title: String
    let author: String
    let points: Int
    let createdAt: Int
    let linkedUrlString: String?
    var postUrlString: String { buildPostUrl(nil, id: id) }
    let relevancyScore: Int?
    let commentCount: Int

    let storyText: String?
    var text: String? { storyText }
    
    let type: Post.PostType = .story

    enum CodingKeys: String, CodingKey {
        case objectID
        case title
        case author
        case points
        case storyText = "story_text"
        case createdAt = "created_at_i"
        case linkedUrlString = "url"
        case relevancyScore = "relevancy_score"
        case commentCount = "num_comments"
    }
}

// MARK: - Comments

struct CommentSearchResult: SearchResultVariant {
    let objectID: String
    var linkedUrlString: String? { storyUrlString }
    let author: String
    let storyText: String?
    let relevancyScore: Int?
    let createdAt: Int
    let parentId: Int?
    let storyTitle: String?
    var title: String { storyTitle ?? "N/A" }
    let storyUrlString: String?
    var postUrlString: String { buildPostUrl(nil, id: id) }
    @HTMLText var text: String?
    let type: Post.PostType = .comment

    
    enum CodingKeys: String, CodingKey {
        case objectID
        case author
        case storyText = "story_text"
        case relevancyScore = "relevancy_score"
        case createdAt = "created_at_i"
        case parentId = "parent_id"
        case storyTitle = "story_title"
        case storyUrlString = "story_url"
        case text = "comment_text"
    }
}

// MARK: - Extensions

extension SearchResultVariant {
    var id: Int { Int(objectID)! }
    
    var urlHost: String? {
        if let linkedUrlString, let url = URL(string: linkedUrlString) {
            return url.host()
        }
        return nil
    }
    
    var urlHostPlain: String? {
        let prefix = "www."
        if let host = urlHost {
            let prettyHost = host.hasPrefix(prefix) ? String(host.dropFirst(prefix.count)) : host
            return prettyHost
        }
        return nil
    }
}
