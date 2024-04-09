//
//  JSONAppStorage.swift
//  HNClient
//
//  Created by Myles Linder on 2023-07-29.
//

import Foundation
import SwiftUI


struct StorageEntityConfig {
    static let shared = StorageEntityConfig()
    // JSONAppStorage property wrapper uses keypath so can't be static
    let seenPosts = Config(type: [SeenPost].self, key: "SeenPosts", defaultValue: [])
    let savedPosts = Config(type: SavedPosts.self, key: "FavouritePosts", defaultValue: SavedPosts())
    let scrollButtonLocation = Config(type: CGPoint?.self, key: "ScrollButtonLocation", defaultValue: nil)

    private init() {}
    
    struct Config<T: Codable> {
        let type: T.Type
        let key: String
        let defaultValue: T
    }
}

// MARK: - Post List Storage

class PostListStorage: ObservableObject {
    let storageKeys = StorageEntityConfig.shared

    @Published var seenPosts: [SeenPost] = StorageEntityConfig.shared.seenPosts.defaultValue {
        didSet {
            storeInUserDefaults(self.seenPosts, key: storageKeys.seenPosts.key)
        }
    }

    @Published var savedPosts: SavedPosts = StorageEntityConfig.shared.savedPosts.defaultValue {
        didSet {
            storeInUserDefaults(self.savedPosts, key: storageKeys.savedPosts.key)
        }
    }

    init() {
        if let seen = restoreFromUserDefaults([SeenPost].self, key: storageKeys.seenPosts.key) {
            self.seenPosts = seen
        }
        if let saved = restoreFromUserDefaults(SavedPosts.self, key: storageKeys.savedPosts.key)  {
            self.savedPosts = saved
        }
    }

    private func storeInUserDefaults<T: Encodable>(_ value: T, key: String) {
        let encodedValue = try? JSONEncoder().encode(value)
        UserDefaults.standard.set(encodedValue, forKey: key)
    }

    private func restoreFromUserDefaults<T: Decodable>(_ type: T.Type, key: String) -> T? {
        if let jsonData = UserDefaults.standard.data(forKey: key) {
            return try? JSONDecoder().decode(type, from: jsonData)
        }
        return nil
    }
}

// MARK: - JSON Storage Property Wrapper


@propertyWrapper
struct JSONAppStorage<DataType: Codable>: DynamicProperty {
    typealias StorageKeyPath = KeyPath<StorageEntityConfig, StorageEntityConfig.Config<DataType>>

    @AppStorage private var data: Data?

    private let itemConfig: StorageEntityConfig.Config<DataType>

    init(_ keypath: StorageKeyPath) {
        let storageKey = StorageEntityConfig.shared[keyPath: keypath]
        self.itemConfig = storageKey
        self._data = AppStorage(storageKey.key)
    }

    var wrappedValue: DataType {
        get {
            if let data {
                return (try? JSONDecoder().decode(DataType.self, from: data)) ?? itemConfig.defaultValue
            }
            return itemConfig.defaultValue
        }
        nonmutating set {
            data = try? JSONEncoder().encode(newValue)
        }
    }

    var projectedValue: Binding<DataType> {
        Binding { wrappedValue }
            set: { wrappedValue = $0 }
    }
}

// MARK: - SeenPost Model

struct SeenPost: Codable, Equatable, Hashable, Identifiable {
    let id: Int
    let lastSeenDate: Date

    static func ==(lhs: SeenPost, rhs: SeenPost) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func toJSON() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func fromJSON(_ data: Data) -> SeenPost? {
        try? JSONDecoder().decode(SeenPost.self, from: data)
    }
}

// MARK: - Saved Post Model

struct SavedPosts: Codable {
    var stories: [PostPreview] = []
    var comments: [PostPreview] = []
}

extension SavedPosts {
    subscript(_ type: Post.PostType) -> [PostPreview] {
        switch type {
        case .comment: return comments
        case .story: return stories
        }
    }
}
