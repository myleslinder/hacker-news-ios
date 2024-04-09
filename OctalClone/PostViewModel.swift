//
//  PostFetcher.swift
//  Mess Around
//
//  Created by Myles Linder on 2023-07-26.
//

import Combine
import Foundation

class PostFetcher: ObservableObject {
    @Published var post: PostVariant?
    @Published var parentPost: PostVariant?
    @Published var fetchStatus: AlgoliaFetch.FetchStatus = .idle
    
    private var fetchCancellable: AnyCancellable?
    
    func fetchPost(id: Int, parent: Bool = false) {
        fetchCancellable?.cancel()
        fetchStatus = .fetching
        let publisher = AlgoliaFetch.postPublisher(id)
            .receive(on: DispatchQueue.main)
            
        fetchCancellable = publisher.sink(receiveCompletion: { [weak self] error in
            switch error {
            case .failure(let error):
                print("Search Error: ", error)
                self?.fetchStatus = .failed(reason: error.localizedDescription)
            default: return
            }
        }) { [weak self] data in
            if parent {
                self?.parentPost = data
            } else {
                self?.post = data
            }   
            self?.fetchStatus = .idle
        }
    }
}
