//
//  PostFetcher.swift
//  HNClient
//
//  Created by Myles Linder on 2023-07-26.
//

import Combine
import Foundation

class PostFetcher: ObservableObject {
    @Published var post: PostVariant?
    @Published var parentPost: PostVariant?
    @Published var fetchStatus: AlgoliaAPI.FetchStatus = .idle
    
    private var fetchCancellable: AnyCancellable?
    
//    var pop: HackerNewsAPI.PopulatedItem?
    
    let session: URLSession
    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
    }
    
//    func newFetch(id: Int) async {
//        do {
//            let startTime = CFAbsoluteTimeGetCurrent()
//            pop = try await HackerNewsAPI.fetchPopulatedItem(id: id)
//            print("pop", CFAbsoluteTimeGetCurrent() -  startTime)
//        } catch {
//            fetchStatus = .failed(reason: error.localizedDescription)
//        }
//    }
    
    func fetchPost(id: Int, parent: Bool = false) {
        fetchStatus = .fetching
        fetchCancellable?.cancel()

        /* Optimization: Fetch the post from AG, the post from HN,
         and search AG for all comments on that post fetching the HN item for
         items with multiple children
        */
        let publisher = AlgoliaAPI.postPublisher(id)
            .zip(HackerNewsAPI.fetchCommentsWithMultipleChildren(id: id, session: URLSession.shared),
                 HackerNewsAPI.fetchItem(id, session: session).map(\.item.childIds))
            .map { postVariant, hnFetchItems, topLevelSortedChildIds in
                var np = postVariant
                np.children = sortToMatch(np.children, ids: topLevelSortedChildIds)
                return sortComments(post: np, sortablePosts: hnFetchItems)
            }
            .receive(on: DispatchQueue.main)

        fetchCancellable = publisher.sink(receiveCompletion: { [weak self] error in
            switch error {
            case .failure(let error):
                print("Search Error: ", error)
                self?.fetchStatus = .failed(reason: error.localizedDescription)
            default: return
            }
        }) { [weak self] data in
            self?.post = data
            self?.fetchStatus = .idle
        }
    }
}
