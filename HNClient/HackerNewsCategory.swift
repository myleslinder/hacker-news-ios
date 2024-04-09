//
//  HackerNewsCategory.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-11.
//

import Foundation

class HackerNewsCategory: ObservableObject {
    typealias CategoryOrderResultsMap = [HackerNewsAPI.StoryCategory: [HackerNewsAPI.StoryOrder: [StorySearchResult]]]
    @Published var categoryOrderResults: CategoryOrderResultsMap  = [:]
    
    @Published var fetchStatus: AlgoliaAPI.FetchStatus = .idle
    
    @MainActor
    func fetch(category: HackerNewsAPI.StoryCategory, order: HackerNewsAPI.StoryOrder) async {
        do {
            fetchStatus = .fetching
            var postIds: [Int]
        
            switch await HackerNewsAPI.fetchItemIds(for: category) {
            case .success(let ids): postIds = ids
            case .failure(let error): throw error
            }
            
            let searchType = AlgoliaSearchType.fromHNSortOrder(order)
            let storyTags: [AlgoliaSearchParam.Tag] = postIds.map { .story_(id: String($0)) }
            let query = AlgoliaSearchParam(searchType: searchType, tagGroups: [.and([.story]), .or(storyTags)])
            
            let searchResults = try await AlgoliaAPI.search(query)
            
            var categoryResults = categoryOrderResults[category] ?? [:]
            var results = searchResults.onlyStories()
            
            if order == .original || order == .search(.recent) {
                categoryResults[.search(.recent)] = results
            }
            if order == .original {
                results = sortToMatch(results, ids: postIds)
            }
            categoryResults[order] = results
            categoryOrderResults[category] = categoryResults
            
            fetchStatus = .idle

        } catch {
            fetchStatus = .failed(reason: error.localizedDescription)
        }
    }
}

//
//class HackerNewsCategoryPub: ObservableObject {
//    @Published var posts: [SearchResult]?
//    @Published var storyOrderResults: [HackerNewsAPIPub.StoryCategory: [HackerNewsAPIPub.StoryOrder: [StorySearchResult]]] = [:]
//
//    @Published var fetchStatus: AlgoliaAPI.FetchStatus = .idle
//
//    private var fetchCancellable: AnyCancellable?
//
//    func fetch(category: HackerNewsAPIPub.StoryCategory, order: HackerNewsAPIPub.StoryOrder) {
//        var searchType: AlgoliaSearchType {
//            switch order {
//            case .original: return .recent
//            case .search(let type): return type
//            }
//        }
//        fetchCancellable?.cancel()
//        fetchStatus = .fetching
//
//        let publisher = HackerNewsAPIPub.fetchCategoryItemIds(for: category)
//            .flatMap { postIds in
//                let storyTags: [AlgoliaSearchParam.Tag] = postIds.map { .story_(id: String($0)) }
//                return AlgoliaAPI.searchResultsPublisher(AlgoliaSearchParam(searchType: searchType, tagGroups: [.and([.story]), .or(storyTags)]))
//                    .map { results in
//                        (ids: postIds, posts: results)
//                    }
//            }
//            .receive(on: DispatchQueue.main)
//
//        fetchCancellable = publisher.sink(receiveCompletion: { [weak self] error in
//            switch error {
//            case .failure(let error):
//                print("Search Error: ", error)
//                self?.fetchStatus = .failed(reason: error.localizedDescription)
//            default: return
//            }
//        }) { [weak self] data in
//            let (ids, originalResults) = data
//            var results = originalResults.compactMap { result in
//                switch result {
//                case .story(let story): return story
//                case .comment: return nil
//                }
//            }
//            self?.posts = originalResults
//            var categoryResults = self?.storyOrderResults[category] ?? [:]
//            if order == .original {
//                results = sortToMatch(results, ids: ids)
//                if order == .search(.recent) {
//                    categoryResults[.search(.recent)] = results
//                }
//            }
//
//            categoryResults[order] = results
//            self?.storyOrderResults[category] = categoryResults
//            self?.fetchStatus = .idle
//        }
//    }
//}
