//
//  AlgoliaSearch.swift
//  HNClient
//
//  Created by Myles Linder on 2023-07-25.
//

import Foundation

@MainActor
class AlgoliaSearch: ObservableObject {
    @Published var results: [SearchResult]?
    @Published var fetchStatus: AlgoliaAPI.FetchStatus = .idle

    var commentResults: [CommentSearchResult]? { results?.onlyComments() }
    var storyResults: [StorySearchResult]? { results?.onlyStories() }
    
    @Published var query: AlgoliaSearchParam? = .none

    func search(_ query: AlgoliaSearchParam) async {
        do {
            self.query = query
            fetchStatus = .fetching
            results = try await AlgoliaAPI.search(query)
            fetchStatus = .idle
        } catch {
            fetchStatus = .failed(reason: error.localizedDescription)
        }
    }
}


//
//class AlgoliaSearch: ObservableObject {
//    @Published var searchResults: [SearchResult]?
//
//    @Published var fetchStatus: AlgoliaAPI.FetchStatus = .idle
//    private var fetchCancellable: AnyCancellable?
//
//    var commentResults: [CommentSearchResult]? {
//        searchResults?.compactMap { result in
//            switch result {
//            case .comment(let comment): return comment
//            default: return nil
//            }
//        }
//    }
//
//    var storyResults: [StorySearchResult]? {
//        searchResults?.compactMap { result in
//            switch result {
//            case .story(let story): return story
//            default: return nil
//            }
//        }
//    }
//
//    func search(_ query: AlgoliaAPI.Endpoint.SearchParam) {
//        fetchCancellable?.cancel()
//        fetchStatus = .fetching
//        let publisher = AlgoliaAPI.searchResultsPublisher(query)
//            .receive(on: DispatchQueue.main)
//
//        fetchCancellable = publisher.sink(receiveCompletion: { [weak self] error in
//            switch error {
//            case .failure(let error):
//                print("Search Error: ", error)
//                self?.fetchStatus = .failed(reason: error.localizedDescription)
//            default: return
//            }
//        }, receiveValue: { [weak self] data in
//            self?.searchResults = data
//            self?.fetchStatus = .idle
//        })
//    }
//}
