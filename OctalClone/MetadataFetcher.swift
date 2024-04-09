//
//  MetadataFetcher.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-06.
//

import Foundation
import LinkPresentation

class UrlLinkMetadata {
    let metadata: LPLinkMetadata?
    let urlString: String

    var previewImage: CachedImage?
    var favicon: CachedImage?

    init(metadata: LPLinkMetadata? = nil, urlString: String) {
        self.metadata = metadata
        self.urlString = urlString
    }
    
    struct CachedImage {
        var image: UIImage?
        init(_ image: UIImage?) {
            self.image = image
        }
    }
}

@MainActor
class AsyncMetadata {
    static var shared = AsyncMetadata()

    let cache = NSCache<NSString, UrlLinkMetadata>()

    func fetchMetadata(for url: URL) async -> UrlLinkMetadata {
        let cacheKey: NSString = url.absoluteString as NSString
        if let cachedVersion = cache.object(forKey: cacheKey) {
            return cachedVersion
        }
        let metadataProvider = LPMetadataProvider()
//        metadataProvider.timeout = 3
        let metadata = try? await metadataProvider.startFetchingMetadata(for: url)
        let linkMetadata = UrlLinkMetadata(metadata: metadata, urlString: cacheKey as String)
        cache.setObject(linkMetadata, forKey: cacheKey)
        return linkMetadata
    }

    private init() {}
}



@MainActor
struct AsyncMetadataImage {
    
    static func fetchMetaImage(url: URL, _ type: MetadataImageType) async -> UIImage? {
        var urlLinkMetadata = await AsyncMetadata.shared.fetchMetadata(for: url)
        if let cachedImage = urlLinkMetadata[keyPath: type.cacheObjectPath] {
            return cachedImage.image
        }
        
        guard let provider = urlLinkMetadata.metadata?[keyPath: type.providerPath],
                provider.canLoadObject(ofClass: UIImage.self)
        else { return nil }

        let image = await loadImage(provider)
        urlLinkMetadata[keyPath: type.cacheObjectPath] = UrlLinkMetadata.CachedImage(image)
        return image
    }
    
    private static func loadImage(_ provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { image, error in
                guard error == nil else { return }
                continuation.resume(returning: image as? UIImage)
            }
        }
    }

    enum MetadataImageType: String {
        case preview
        case favicon
    }
}


extension AsyncMetadataImage.MetadataImageType {
    var providerPath: KeyPath<LPLinkMetadata, NSItemProvider?> {
        switch self {
        case .favicon: return \.iconProvider
        case .preview: return \.imageProvider
        }
    }

    var cacheObjectPath: WritableKeyPath<UrlLinkMetadata, UrlLinkMetadata.CachedImage?> {
        switch self {
        case .favicon: return \.favicon
        case .preview: return \.previewImage
        }
    }
}
