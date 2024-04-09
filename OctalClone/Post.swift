//
//  Post.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-05.
//

import Foundation

// MARK: - Post

enum Post: Decodable, Identifiable {
    case story(StoryPost)
    case comment(CommentPost)
    
    var id: Int {
        switch self {
        case .story(let story): return story.id
        case .comment(let comment): return comment.id
        }
    }

    var variant: PostVariant {
        switch self {
        case .comment(let c): return c
        case .story(let s): return s
        }
    }

    enum PostType: String, CaseIterable, Codable, SystemImageConvertible {
        case story
        case comment
        
        var id: Self { self }
        
        var systemImage: String {
            switch self {
            case .story: return "doc.on.doc"
            case .comment: return "bubble.left.and.bubble.right"
            }
        }
    }
}

extension Post {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let postType: Post.PostType = try container.decode(Post.PostType.self, forKey: .type)

        switch postType {
        case .story:
            self = try .story(StoryPost(from: decoder))
        case .comment:
            self = try .comment(CommentPost(from: decoder))
        }
    }
    
    private enum CodingKeys: CodingKey {
        case type
    }
}

// MARK: - Post Variants

protocol PostVariant: Decodable {
    var id: Int { get }
    var createdAt: Int { get }
    var postUrlString: String { get }
    var author: String { get }
    var type: Post.PostType { get }
    var text: String? { get }
    var htmlText: AttributedString? { get }
    var children: [CommentPost] { get set }
}

// MARK: - Story

func buildPostUrl(_ urlString: String?, id: Int) -> String {
    urlString ?? "https://news.ycombinator.com/item?id=\(id)"
}

struct StoryPost: PostVariant {
    let id: Int
    private var _postUrlString: String?
    var postUrlString: String { _postUrlString ?? buildPostUrl(nil, id: id) }
    let createdAt: Int
    let author: String
    var type: Post.PostType = .story
    var children: [CommentPost]

    @HTMLText var text: String?
    let points: Int
    var previewPoints: Int? { Optional(points) }
    let title: String
    var htmlText: AttributedString? { $text }
    let linkedUrlString: String?

    enum CodingKeys: String, CodingKey {
        case id
        case linkedUrlString = "url"
        case createdAt = "created_at_i"
        case author
        case type
        case title
        case text
        case points
        case children
    }
}

// MARK: - Comment

struct CommentPost: PostVariant, Identifiable {
    let id: Int
    private let _author: String?
    var author: String { _author ?? "__deleted__" }
    let storyId: Int?
    let createdAt: Int
    private var _postUrlString: String?
    var postUrlString: String { _postUrlString ?? buildPostUrl(nil, id: id) }
    var type: Post.PostType = .comment
    var children: [CommentPost]

    @HTMLText var text: String?
    var htmlText: AttributedString? { $text }
    
    
    init(from result: CommentSearchResult, children: [CommentPost]) {
        id = result.id
        _author = result.author
        storyId = .none
        createdAt = result.createdAt
        self.children = children
        _postUrlString = result.postUrlString
        self._text = HTMLText(result.text)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case createdAt = "created_at_i"
        case _author = "author"
        case type
        case text
        case children
    }
}

// MARK: - Post Previews

// TODO: how to use @HTMLText?
struct PostPreview: Codable, Equatable, Hashable, Identifiable {
    init(id: Int, author: String, type: Post.PostType, createdAt: Int, title: String, linkedUrlString: String? = nil, postUrlString: String, text: String? = nil, commentCount: Int? = nil, points: Int? = nil, htmlText: AttributedString? = nil) {
        self.id = id
        self.author = author
        self.type = type
        self.createdAt = createdAt
        self.title = title
        self.linkedUrlString = linkedUrlString
        self.postUrlString = postUrlString
        self.text = text
        self.commentCount = commentCount
        self.points = points
        self.htmlText = htmlText
    }
    
    let id: Int
    let author: String
    let type: Post.PostType
    let createdAt: Int

    let title: String
    let linkedUrlString: String?
    let postUrlString: String
    let text: String?
    let commentCount: Int?
    let points: Int?
    let htmlText: AttributedString?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.author = try container.decode(String.self, forKey: .author)
        self.type = try container.decode(Post.PostType.self, forKey: .type)
        self.createdAt = try container.decode(Int.self, forKey: .createdAt)
        self.title = try container.decode(String.self, forKey: .title)
        self.linkedUrlString = try container.decodeIfPresent(String.self, forKey: .linkedUrlString)
        self.postUrlString = try container.decode(String.self, forKey: .postUrlString)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
        self.points = try container.decodeIfPresent(Int.self, forKey: .points)
        if let htmlText = try container.decodeIfPresent(AttributedString.self, forKey: .htmlText) {
            self.htmlText = styleHtmlText(htmlText)
        } else {
            self.htmlText = nil
        }
    }
}

// TODO: protocol or how to avoid so much duplication?
extension PostPreview {
    init(from searchResult: any SearchResultVariant) {
        self.id = searchResult.id
        self.author = searchResult.author
        self.createdAt = searchResult.createdAt
        self.title = searchResult.title
        self.linkedUrlString = searchResult.linkedUrlString
        self.postUrlString = searchResult.postUrlString
        self.text = searchResult.text
        if let story = searchResult as? StorySearchResult {
            self.commentCount = story.commentCount
            self.points = story.points
            self.type = .story
            
        } else {
            self.type = .comment
            self.commentCount = nil
            self.points = nil
        }
        self.htmlText = nil
    }

    init(from post: PostVariant, title: String, urlString: String? = nil) {
        self.id = post.id
        self.author = post.author
        self.type = post.type
        self.createdAt = post.createdAt
        self.text = post.text
        self.htmlText = post.htmlText
        self.title = title
        if let story = post as? StoryPost {
            self.points = story.points
            self.linkedUrlString = urlString ?? story.linkedUrlString
        } else {
            self.points = nil
            self.linkedUrlString = urlString
        }
        self.postUrlString = post.postUrlString
        self.commentCount = nil
    }
}

extension PostPreview {
    var urlHost: String? {
        if let linkedUrlString, let url = URL(string: linkedUrlString) {
            return url.host()
        }
        return nil
    }

    var hostIsHn: Bool { urlHost?.contains("news.ycombinator.com") ?? false }

    var urlHostPlain: String? {
        let prefix = "www."
        if let host = urlHost {
            let prettyHost = host.hasPrefix(prefix) ? String(host.dropFirst(prefix.count)) : host
            return prettyHost
        }
        return nil
    }
}
