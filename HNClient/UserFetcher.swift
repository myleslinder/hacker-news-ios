//
//  UserFetcher.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-01.
//

import Foundation

enum UserFetchError: Error, LocalizedError {
    case app(String)
    case response(String)
    case algolia(String)
    case hn(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .app: return "Application Error"
        case .algolia: return "Error message from Algolia"
        case .hn: return "Error message from Hacker News"
        case .network: return "Network Error"
        case .response: return "Resource Error"
        }
    }

    var failureReason: String {
        switch self {
        case .app(let reason): return reason
        case .response(let reason): return reason
        case .algolia(let reason): return reason
        case .hn(let reason): return reason
        case .network(let reason): return reason
        }
    }
    
    var canRetry: Bool {
        false
    }
}

@MainActor
class UserFetcher: ObservableObject {
    @Published var user: User?
    @Published var hnUser: HackerNewsAPI.HackerNewsUser?
    @Published var fetchStatus: UserFetchStatus = .idle

    
    func fetchUser(id: String, type: UserType = .algolia) async {
        fetchStatus = .fetching
        do {
            if type == .algolia || type == .all {
                switch await AlgoliaAPI.user(id: id) {
                case .success(let user): self.user = user
                case .failure(let error): throw error // the UserFetchError
                }
            }
            if type == .hn || type == .all {
                switch await HackerNewsAPI.fetchUser(id) {
                case .success(let user): self.hnUser = user
                case .failure(let error): throw error // the UserFetchError
                }
            }
            fetchStatus = .idle
        } catch let error as UserFetchError {
            fetchStatus = .failed(reason: error.failureReason, description: error.errorDescription)
        } catch {
            fetchStatus = .failed(reason: error.localizedDescription)
        }
    }

    enum UserFetchStatus: Equatable {
        case idle
        case fetching
        case failed(reason: String, description: String? = .none)
    }
    
    enum UserType {
        case algolia
        case hn
        case all
    }
}

//                    if let reason = error.networkUnavailableReason {
//                        switch reason {
//                        case .cellular: break
//                        case .constrained: break
//                        case .expensive: break
//                        @unknown default: break
//                        }
//                    }
