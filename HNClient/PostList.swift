//
//  PostList.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-04.
//

import LinkPresentation
import SwiftUI

struct PostList<Content: View>: View {
    @StateObject private var storage = PostListStorage()

    let results: [StorySearchResult]?
    var indicatorStyle: PostLinkLabel.PostIndicatorStyle = .automatic
    @ViewBuilder var listHeader: () -> Content

    @State private var postLinkToOpen: PostLink? = nil
    @State private var internalResults: [StorySearchResult]? = .none

    init(_ results: [StorySearchResult]?, indicatorStyle: PostLinkLabel.PostIndicatorStyle = .automatic, listHeader: @escaping () -> Content = { EmptyView() }) {
        self.results = results
        self.indicatorStyle = indicatorStyle
        self.listHeader = listHeader
        self._internalResults = State(initialValue: results) // Should this be wrapped value???
    }

    var body: some View {
        GeometryReader { geometry in
            let header = listHeader()
            if let internalResults, !internalResults.isEmpty {
                List {
                    contentList(internalResults) {
                        header
                    }
                }
                .transition(.identity)
            } else {
                List {
                    header
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    ForEach(1 ..< 10) { _ in
                        LoadingFrame(geometry: geometry)
                    }
                }
                .transition(.identity)
            }
        }
        .onChange(of: results) { [results] newValue in
            if (results == nil || (results?.isEmpty ?? false)) && newValue != nil {
                withAnimation(.easeInOut) {
                    internalResults = newValue
                }
            } else {
                internalResults = newValue
            }
        }
        .coordinateSpace(name: "ListView")
    }

    @ViewBuilder
    private func contentList<Header: View>(_ results: [StorySearchResult], @ViewBuilder header: @escaping () -> Header) -> some View {
        header()
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        ForEach(Array(results.enumerated()), id: \.element) { idx, result in
            let postPreview = PostPreview(from: result)
            BubblingNavLink(value: postPreview) {
                PostLinkLabel(seenPosts: storage.seenPosts, savedPosts: storage.savedPosts, result: postPreview, resultIndex: idx + 1, indicatorStyle: indicatorStyle)
                    .foregroundColor(.secondary)
            }
            .padding(.all)
            .swipeActions(edge: .leading) {
                leadingSwipeActions(for: postPreview)
            }
            .swipeActions(edge: .trailing) {
                trailingSwipeActions(for: postPreview)
            }
            .listRowSeparator(idx == 0 ? .hidden : .visible, edges: [.top])
            .tag(result)
            .contextMenu(menuItems: {
                NavigationLink(value: postPreview) {
                    Text("Go to Story")
                }
                if let urlString = postPreview.linkedUrlString, let url = URL(string: urlString) {
                    SheetNavigationLink(value: url) {
                        Text("Open Link")
                    }
                }

            }, preview: {
                if let urlString = postPreview.linkedUrlString, let url = URL(string: urlString) {
                    SFSafariViewWrapper(url: url)
                } else {
                    EmptyView()
                }
            })
            .id(idx)
        }
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    @ViewBuilder
    private func trailingSwipeActions(for postPreview: PostPreview) -> some View {
        SaveButton(post: postPreview)
            .tint(.orange)
        SheetNavigationLink(value: NavigableHNUser(id: postPreview.author)) {
            VStack {
                Image(systemName: "person.fill")
                Text("View User")
            }
        }
        .tint(Color.darkGray)

        if let url = URL(string: postPreview.linkedUrlString ?? postPreview.postUrlString) {
            ShareLink("Share", item: url)
                .tint(.gray)
        }
    }

    @ViewBuilder
    private func leadingSwipeActions(for postPreview: PostPreview) -> some View {
        if let url = URL(string: postPreview.linkedUrlString ?? postPreview.postUrlString) {
            NavigationLink(value: url) {
                VStack {
                    Image(systemName: "safari.fill")
                    Text("Open Link")
                }
            }
            .tint(.blue)
//                Button {
//                    TabSelection.shared.payloads[.search]?.setPayload(postPreview.title)
//                    TabSelection.shared.updateSelections(current: .search)
//                } label: {
//                    VStack {
//                        Image(systemName: "text.magnifyingglass")
//                        Text("Search HN")
//                    }
//                }
//                .tint(.teal)
            VStack {
                Button {
                    Task {
                        if let auth = await Login.fetchPage(id: "\(postPreview.id)") {
                            print(auth)
                        } else {
                            print("NO AUTH??")
                        }
                    }
                } label: {
                    VStack {
                        Image(systemName: "space")
                        Text("Upvote")
                    }
                }
                .tint(.teal)

                NavigationLink(value: URL(string: "https://www.google.com/search?q=\(url.absoluteString)")!) {
                    VStack {
                        Image(systemName: "globe")
                        Text("Search Web")
                    }
                }
                .tint(.mint)
            }
        }
    }

    private struct PostLink: Identifiable {
        let id: Int
        let url: URL
    }
}

// MARK: - Post Link Label

struct PostLinkLabel: View {
    var seenPosts: [SeenPost]
    var savedPosts: SavedPosts

    let result: PostPreview
    var resultIndex: Int? = nil
    var indicatorStyle = PostIndicatorStyle.automatic

    @State private var previewImage: UIImage?

    private var seenPost: SeenPost? { seenPosts.first(where: { $0.id == result.id }) }
    private var hasSeenPost: Bool {
        if seenPost != nil {
            switch indicatorStyle {
            case .seenOnly: return true
            case .seenAndSaved: return true
            default: return false
            }
        }
        return false
    }

    private var isSaved: Bool {
        if savedPosts.stories.contains(where: { $0.id == result.id }) {
            switch indicatorStyle {
            case .savedOnly: return true
            case .seenAndSaved: return true
            default: return false
            }
        }
        return false
    }

    private var titleForegroundColor: Color {
        if !hasSeenPost {
            return .primary
        }
        switch indicatorStyle {
        case .seenAndSaved(let opacity): return opacity ? .secondary : .primary
        case .seenOnly(let opacity): return opacity ? .secondary : .primary
        default: return .primary
        }
    }

    // TODO: magic numbers
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topBar
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(result.title)
                        .fontWeight(.semibold)
                        .foregroundColor(titleForegroundColor)
                    PostDetails(author: result.author, points: result.points, commentCount: result.commentCount, createdAt: result.createdAt, isSaved: isSaved)
                }
                if let previewImage {
                    Spacer()
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill) // 1.91/1 ratio)
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    //                            .delay(0.2)))
                }
            }
        }
//            .padding(.vertical, 5)

        .task {
            if let urlString = result.linkedUrlString, let url = URL(string: urlString) {
                previewImage = await AsyncMetadataImage.fetchMetaImage(url: url, .preview)
            }
        }
    }

    private var topBar: some View {
        HStack {
            if let resultIndex {
                Text("\(resultIndex).")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            HStack {
                PostExternalLink(urlString: result.linkedUrlString ?? result.postUrlString, disabled: true)
                if hasSeenPost, let seenPost {
                    let lastSeenDateString = seenPost.lastSeenDate.formatted(.relative(presentation: .numeric))
                    Spacer()
                    Text(lastSeenDateString)
                        .font(.caption.italic())
                        .foregroundColor(.gray)
                }
            }
        }
    }

    enum PostIndicatorStyle {
        case seenOnly(opacity: Bool = true)
        case savedOnly
        case seenAndSaved(opacity: Bool = true)
        case none

        static var automatic: PostIndicatorStyle { .seenAndSaved(opacity: true) }
    }
}

// MARK: - Post External Link

struct PostExternalLink: View {
    let urlString: String
    var disabled: Bool = false

    @ViewBuilder
    func content(urlHost: String) -> some View {
        let prefix = "www."
        let prettyHost = urlHost.hasPrefix(prefix) ? String(urlHost.dropFirst(prefix.count)) : urlHost
        Text(prettyHost)
            .foregroundColor(.accentColor)
            .padding(.leading, 2)
            .font(.callout)
            .lineLimit(1)
    }

    var body: some View {
        if let url = URL(string: urlString),
           let urlHost = url.host()
        {
            if disabled {
                content(urlHost: urlHost)
            } else {
                NavigationLink(value: url) {
                    content(urlHost: urlHost)
                }
            }
        }
    }
}

// MARK: - Post Details

struct PostDetails: View {
    let author: String
    let points: Int?
    let commentCount: Int?
    let createdAt: Int
    var isSaved: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(author)
                    .fontWeight(.medium)
                dot
                Text(formattedDateString(createdAt))
            }
            HStack {
                if let points {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                        Text("\(points)")
                    }
                }
                if let commentCount {
                    dot
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("\(commentCount)")
                    }
                }
                if isSaved {
                    dot
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.orange)
                }
            }
        }
        .fontWeight(.medium)
    }

    private var dot: some View {
        Circle()
            .frame(width: 3.5)
    }
}
