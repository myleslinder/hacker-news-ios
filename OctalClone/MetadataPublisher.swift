//
//  MetadataPublisher.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-23.
//

import Foundation
import Combine
import LinkPresentation

struct PostMetadata {
    var previewImage: UIImage?
    var favicon: UIImage?
}


class UNUSEDMetadataFetcher: ObservableObject {
    @Published var urlToMetadata: [String: PostMetadata] = [:]
    var urlToMetadataProvider: [String: LPMetadataProvider] = [:]

    private var urlToCancellable: [String: (icon: AnyCancellable?, image: AnyCancellable?)] = [:]
    private var faviconCache: [String: UIImage] = [:]

    func getMetadata(for urlString: String?) -> PostMetadata? {
        if let urlString {
            return urlToMetadata[urlString]
        }
        return nil
    }

    private func cancelMetadataFetch(_ absoluteUrl: String) {
        let cancellables = urlToCancellable[absoluteUrl]
        cancellables?.icon?.cancel()
        cancellables?.image?.cancel()
    }

    func fetchUrlMetadata(urlString: String?) {
//        return
        if let urlString, let url = URL(string: urlString), urlToMetadata[url.absoluteString] == nil {
            let absoluteUrl = url.absoluteString
            if urlToMetadata[absoluteUrl] != nil {
                return
            }
            cancelMetadataFetch(absoluteUrl)

            urlToMetadata[absoluteUrl] = PostMetadata()

            let metadataProvider: LPMetadataProvider = urlToMetadataProvider[absoluteUrl] ?? LPMetadataProvider()
            urlToMetadataProvider[absoluteUrl] = metadataProvider

            metadataProvider.timeout = 3
            let publisher = metadataProvider.metadataPublisher(url: url)

            // TODO: could get metadata separately from constructing the images?
//            publisher
//                .receive(on: DispatchQueue.main)
//                .sink { error in
//                    //
//                } receiveValue: { metadata in
//                    //
//                }

            var iconCancellable: AnyCancellable? = nil
            if let urlHost = url.host() {
                if let favicon = faviconCache[urlHost] {
                    urlToMetadata[absoluteUrl]?.favicon = favicon
                } else {
                    iconCancellable = retrieveMetadataImage(provider: \.iconProvider, publisher) { [weak self] image in
                        self?.urlToMetadata[absoluteUrl]?.favicon = image
                        self?.faviconCache[urlHost] = image
                    }
                }
            }

            let imageCancellable = retrieveMetadataImage(provider: \.imageProvider, publisher) { [weak self] image in
                self?.urlToMetadata[absoluteUrl]?.previewImage = image
            }
            urlToCancellable[absoluteUrl] = (icon: iconCancellable, image: imageCancellable)
        }
    }
}

// MARK: - Metadata Provider

extension LPMetadataProvider {
    func metadataPublisher(url: URL) -> AnyPublisher<LPLinkMetadata?, Error> {
        Future<LPLinkMetadata?, Error> { [weak self] promise in
            self?.startFetchingMetadata(for: url) { metadata, error in
                if let error {
                    promise(.failure(error))
                    return
                }
                promise(.success(metadata))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - ItemProvider Publisher

func itemProviderImagePublisher(provider: NSItemProvider?) -> AnyPublisher<UIImage?, Error> {
    Future<UIImage?, Error> { promise in
        if let provider, provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { image, error in
                if let error {
                    return promise(.failure(error))
                }
                if let image {
                    promise(.success(image as? UIImage))
                } else {
                    promise(.success(nil))
                }
            }
        } else {
            promise(.success(nil))
        }
    }
    .eraseToAnyPublisher()
}

func retrieveMetadataImage(provider: KeyPath<LPLinkMetadata, NSItemProvider?>, _ metadataPublisher: AnyPublisher<LPLinkMetadata?, Error>, _ recieve: @escaping (UIImage?) -> Void) -> AnyCancellable {
    metadataPublisher
        .flatMap { metadata in
            itemProviderImagePublisher(provider: metadata?[keyPath: provider])
        }
        .replaceError(with: nil)
        .receive(on: RunLoop.main)
        .sink(receiveValue: recieve)
}
