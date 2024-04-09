//
//  PostDetailScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-07-25.
//

import Combine
import SwiftUI

struct PostDetailScreen: View {
    @Environment(\.navigateInCurrentTab) private var navigateInCurrentTab
    
    let preview: PostPreview
    let containingGeometry: GeometryProxy
    
    @StateObject private var postVm: PostFetcher = .init()
    @JSONAppStorage(\.seenPosts) private var seenPosts
    
    @State private var collapsedCommentIds: Set<Int> = []
    @State private var scrollToCommentId: Int?
    private var post: PostVariant? { postVm.post }
    private var story: StoryPost? { post as? StoryPost }
    private var comment: CommentPost? { post as? CommentPost }
    
    // MARK: - Scroll Button Location
    
    @JSONAppStorage(\.scrollButtonLocation) private var storedScrollButtonLocation
    var scrollButtonLocationPublisher = PassthroughSubject<CGPoint?, Never>()
    @State private var scrollButtonLocation: CGPoint?
    @State private var scrollButtonLocationCancellable: AnyCancellable? = .none
        
    // MARK: - Hero Offset & Height

    @State private var heroYOffset: CGFloat?
    @State private var initialHeroYOffset: CGFloat?
    @State private var heroHeight: CGFloat = .zero
    
    var navBarOpacity: Double {
        if let heroYOffset, let initialHeroYOffset {
            return (initialHeroYOffset - heroYOffset) / initialHeroYOffset
        }
        return .zero
    }

    var scrollDistance: Double {
        (initialHeroYOffset ?? 0) - (heroYOffset ?? 0)
    }

    var opacity: Double { scrollDistance > 0 ? abs(scrollDistance) / 150 : 0 }
    var symbolOpacity: Double { scrollDistance > 75 ? abs(scrollDistance - 75) / 130 : 0 }
    @State private var toolbarColorScheme: Color = .primary
    @State private var isLastScroll: Task<(), Never>?
    @State private var canScroll: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollViewProxy in
                ZStack(alignment: .topLeading) {
                    let showBgImage = heroHeight > 0
                    if let heroYOffset, let initialHeroYOffset, showBgImage {
                        Color.clear
                            .background {
                                GeometryReader { innerGeo in
                                    HeroImage(urlString: preview.linkedUrlString, width: innerGeo.size.width)
                                        .opacity(0.5)
                                        .frame(width: innerGeo.size.width, height: heroYOffset > initialHeroYOffset ? heroYOffset + heroHeight : initialHeroYOffset + heroHeight, alignment: .center) // TODO: sometimes invalid?
                                        .blur(radius: 10)
                                        .overlay(Material.ultraThin)
                                        .clipped()
                                        .offset(y: min((heroYOffset - initialHeroYOffset) / 3, 0))
                                }
                                .clipped()
                            }
                            .transition(.opacity.animation(.easeInOut))
                    }
                    ScrollView {
                        DesinationNavBarView(scrollDistance: scrollDistance, threshold: 175)
                            .frame(width: 0, height: 0)
                        LazyVStack(alignment: .leading, spacing: 0) {
                            postHero()
                            Group {
                                switch postVm.fetchStatus {
                                case .idle:
                                    if let post = postVm.post {
                                        commentList(post, geometry: geometry)
                                            .background { Rectangle().fill(Color(uiColor: UIColor.systemBackground)) }
                                            .transition(PostPageConstants.entryTransition)
                                            .id("top")
                                    }
                                case .fetching: EmptyView()
                                    .loading(postVm.fetchStatus == .fetching)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top)
                                case .failed(reason: _): SomethingWentWrong()
                                }
                            }
                        }
                    }
                    .padding(.top, containingGeometry.safeAreaInsets.top)
                    .scrollContentBackground(.visible)
                    
                    if let post = postVm.post, !post.children.isEmpty {
                        scrollToCommentButton(post, geometry: geometry)
                            .onTapGesture { commentScrollTap(post, scrollProxy: scrollViewProxy) }
                    }
                    if let heroYOffset {
                        let h = (heroYOffset - containingGeometry.safeAreaInsets.top)
                        Rectangle()
                            .fill(Material.ultraThin)
//                            .fill(.clear)
                            .frame(width: geometry.size.width, height: containingGeometry.safeAreaInsets.top)
                            .opacity(h < 0 ? opacity : 0)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        if let navigateInCurrentTab {
                            Button {
                                navigateInCurrentTab(preview)
                            } label: {
                                Image(systemName: "pip.exit")
                            }
                        } else {
                            EmptyView()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            SaveButton(post: preview)
                            toolbarItemGroup
                                .onAppear { onToolbarAppear() }
                        }
                        .font(.title2)
                        .environment(\.colorScheme, colorScheme == .dark ? .light : .dark)
                        .foregroundStyle(toolbarColorScheme, Material.thin.opacity(max(0.2, 1 - symbolOpacity * 1.5)))
                        .onChange(of: scrollDistance) { distance in
//                            let threshold: Double = 130
                            let op = colorScheme == .dark ? min(1, 0 + symbolOpacity) : max(0, 1 - symbolOpacity)
                            toolbarColorScheme = Color(hue: 0, saturation: 0, brightness: op)
//                            if distance < threshold, !canScroll {
//                                canScroll = true
//                            }
//                            if scrollDistance > distance {
//                                isLastScroll?.cancel()
//                            }
//                            
//                            if canScroll, distance > threshold {
//                                let task = Task {
//                                    try? await Task.sleep(for: .milliseconds(100))
//                                    if !Task.isCancelled, isLastScroll != nil, distance < 235 {
//                                        withAnimation {
//                                            scrollViewProxy.scrollTo("top", anchor: .top)
//                                        }
//                                        canScroll = false
//                                    }
//                                }
//                                isLastScroll?.cancel()
//                                isLastScroll = task
//                            }
                        }
                    }
                }
            }
//            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear { onPageAppear() }
        }
        .navigationBarTitleDisplayMode(.inline)
//        .navigationTitle(preview.type == .story ? "Story" : "Comment Thread")
        .navigationTitle("")
//        .tint(.white)
        
//        .refreshable {  postVm.fetchItem(id: "\(preview.id)") }
    }
    
    private func onPageAppear() {
        seenPosts.update(with: SeenPost(id: preview.id, lastSeenDate: Date.now), position: .prepend)
        if post == nil {
            postVm.fetchPost(id: preview.id)
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbarItemGroup: some View {
        Menu {
            if let parent = postVm.parentPost {
                NavigationLink(value: PostPreview(from: parent, title: preview.title)) {
                    Label("View Parent Story", systemImage: "chevron.right")
                }
            }
            SheetNavigationLink(value: NavigableHNUser(id: preview.author)) {
                Text("View User")
            }
            if let linkedUrlString = preview.linkedUrlString, let url = URL(string: linkedUrlString) {
                ShareLink("Share Link", item: url)
                Button {
                    TabSelection.shared.payloads[.search]?.setPayload(preview.title)
                    TabSelection.shared.updateSelections(current: .search)
                } label: {
                    VStack {
                        Image(systemName: "text.magnifyingglass")
                        Text("Search HN")
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
            if let url = URL(string: preview.postUrlString) {
                ShareLink("Share Story", item: url)
            }

            if story == nil, let url = URL(string: preview.postUrlString) {
                ShareLink("Share Comment Thread", item: url)
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
//            .foregroundStyle(.tint, Material.thin)
                .rotationEffect(Angle(degrees: 90))
        }
        .menuStyle(.borderlessButton)
//        .transition(PostPageConstants.entryTransition)
    }
    
    private func onToolbarAppear() {
        if let comment, let storyId = comment.storyId {
            postVm.fetchPost(id: storyId, parent: true)
        }
    }
    
    // MARK: - Post Hero
    
    private func postHero() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(preview.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    FaviconImage(urlString: preview.linkedUrlString)
                    PostExternalLink(urlString: preview.linkedUrlString ?? preview.postUrlString)
                }
                PostDetails(author: preview.author, points: preview.points, commentCount: preview.commentCount, createdAt: preview.createdAt)
            }
            .offset(y: min(((heroYOffset ?? 0) - (initialHeroYOffset ?? 0)) / 12, 0))
            .padding(.top, 50)
            .padding(.bottom, 35)
            .padding(.horizontal)
            .background {
                GeometryReader { geometry in
                    let yOffset = geometry.frame(in: .global).origin.y
                    let height = geometry.size.height
                    Color.clear
                        .onChange(of: yOffset) { newOffset in
                            if initialHeroYOffset == nil {
                                initialHeroYOffset = newOffset
                            }
                            heroYOffset = newOffset
                        }
                        .onAppear {
                            heroHeight = height
                        }
                }
                
                .clipped()
            }
            if let html = preview.htmlText ?? post?.htmlText {
                VStack(spacing: 0) {
                    Text(html)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background { Rectangle().fill(Color(uiColor: UIColor.systemBackground)) }
                        .transition(PostPageConstants.entryTransition)
                    Rectangle()
                        .fill(.secondary)
                        .frame(height: 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Comment List
    
    private func commentList(_ post: PostVariant, geometry: GeometryProxy) -> some View {
        ForEach(post.children) { child in
            PostComment(comment: child, postTitle: preview.title, postUrlString: preview.linkedUrlString, postAuthor: preview.author, collapsedCommentIds: $collapsedCommentIds)
                .background {
                    if let currentIndex = post.children.firstIndex(where: { $0.id == child.id }) {
                        let isLastComment = post.children.finalIndex == currentIndex
                        let nextCommentId = isLastComment ? nil : post.children[post.children.index(after: currentIndex)].id
                        CommentBackgroundGeo(topBuffer: containingGeometry.safeAreaInsets.top, commentId: child.id, nextCommentId: nextCommentId, scrollToCommentId: $scrollToCommentId)
                    }
                }
        }
    }
    
    // MARK: - Scroll To Comment Button
    
    
    private func scrollToCommentButton(_ post: PostVariant, geometry: GeometryProxy) -> some View {
        OverlayButton("chevron.down", dimension: PostPageConstants.overlayButtonSize, offset: .zero)
            .position(scrollButtonLocation ?? PostPageConstants.getScrollToButtonPosition(geometry: geometry))
            .transition(PostPageConstants.entryTransition)
            .gesture(scrollToCommentDrag(geometry: geometry))
            .onAppear {
                onScrollToButtonAppear(post)
            }
            .onDisappear {
                scrollButtonLocationPublisher.send(scrollButtonLocation)
            }
            .onChange(of: scrollButtonLocation) { _ in
                scrollButtonLocationPublisher.send(scrollButtonLocation)
            }
    }
    
    private func onScrollToButtonAppear(_ post: PostVariant) {
        scrollButtonLocation = storedScrollButtonLocation
        scrollButtonLocationCancellable = scrollButtonLocationPublisher
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { self.storedScrollButtonLocation = $0 }
        
        if scrollToCommentId == nil {
            scrollToCommentId = post.children[0].id
        }
    }
    
    private func scrollToCommentDrag(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { v in
                withAnimation(.interactiveSpring()) {
                    scrollButtonLocation = v.location
                }
            }
            .onEnded { value in
                let offset: Double = 40
                let predictedEnd = value.predictedEndLocation
                let destinationX = predictedEnd.x < 0 ? offset : min(predictedEnd.x, geometry.size.width - offset)
                let navbarHeight = containingGeometry.safeAreaInsets.top
                let isOutsideYBoundTop = predictedEnd.y < 0 || value.location.y < navbarHeight
                let destinationY = isOutsideYBoundTop
                    ? containingGeometry.safeAreaInsets.top + offset
                    : min(predictedEnd.y, (geometry.size.height - geometry.safeAreaInsets.bottom) + offset)
                withAnimation(.spring(dampingFraction: 0.6, blendDuration: 0.5)) {
                    scrollButtonLocation = CGPoint(x: destinationX, y: destinationY)
                }
            }
    }
  
    private func commentScrollTap(_ post: PostVariant, scrollProxy: ScrollViewProxy) {
        if let commentIndex = post.children.firstIndex(where: { $0.id == scrollToCommentId }) {
            withAnimation {
                scrollProxy.scrollTo(post.children[commentIndex].id, anchor: .top)
            }
            if post.children.finalIndex != commentIndex {
                let nextCommentIndex = post.children.index(after: commentIndex)
                scrollToCommentId = post.children[nextCommentIndex].id
            }
        }
    }
    
    // MARK: - Constants
    
    private enum PostPageConstants {
        static let entryTransition = AnyTransition.opacity.animation(.easeInOut)
        static let exitTransition = AnyTransition.opacity.animation(.easeInOut)
        static let overlayButtonSize: CGFloat = 40
        static func getScrollToButtonPosition(geometry: GeometryProxy) -> CGPoint {
            .init(x: geometry.size.width - PostPageConstants.overlayButtonSize, y: geometry.size.height - PostPageConstants.overlayButtonSize)
        }
    }
}

// MARK: - Sub Views to Move?

private struct PostComment: View {
    let comment: CommentPost
    var parentId: Int? = .none
    let postTitle: String
    let postUrlString: String?
    let postAuthor: String
    @Binding var collapsedCommentIds: Set<Int>
    
    private var threadPreview: PostPreview { PostPreview(from: comment, title: postTitle, urlString: postUrlString) }
    private var isExpanded: Bool { !collapsedCommentIds.contains(comment.id) }
    private var parentIsExpanded: Bool {
        if let parentId {
            return !collapsedCommentIds.contains(parentId)
        }
        return true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let html = comment.htmlText {
                CommentHeader(comment: comment, postAuthor: postAuthor, threadPreview: threadPreview, collapsedCommentIds: $collapsedCommentIds, isExpanded: isExpanded)
                VStack(alignment: .leading, spacing: 0) {
                    if isExpanded && parentIsExpanded {
                        Text(html)
                            .padding(.horizontal)
                            .padding(.bottom)
                        LazyVStack(alignment: .leading) {
                            if !comment.children.isEmpty {
                                ForEach(comment.children) { child in
                                    PostComment(comment: child, parentId: comment.id, postTitle: postTitle, postUrlString: postUrlString, postAuthor: postAuthor, collapsedCommentIds: $collapsedCommentIds)
                                }
                            }
                        }
                        .overlay(
                            Rectangle()
                                .frame(width: 2, height: nil, alignment: .leading)
                                .foregroundColor(.gray.opacity(0.2))
                                .padding(.leading, -2),
                            
                            alignment: .leading
                        )
                        .padding(.leading)
                    }
                }
            }
        }
    }
}

private struct CommentHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let comment: CommentPost
    let postAuthor: String
    let threadPreview: PostPreview
    @Binding var collapsedCommentIds: Set<Int>
    let isExpanded: Bool
    
    var buttonBackgroundColor: Color {
        colorScheme == .dark ? .secondary : Color(uiColor: UIColor.systemGray4)
    }
    
    var body: some View {
        HStack {
            HStack {
                if postAuthor == comment.author { postOpIndicator }
                Text(comment.author)
                Text(formattedDateString(comment.createdAt))
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .fontWeight(.light)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    if isExpanded {
                        collapsedCommentIds.insert(comment.id)
                    } else {
                        collapsedCommentIds.remove(comment.id)
                    }
                }
            }
            HStack {
                asButton {
                    SaveButton(post: threadPreview)
                        .labelStyle(.iconOnly)
                }
                Menu {
                    NavigationLink(value: threadPreview) {
                        Text("View Thread")
                    }
                    SheetNavigationLink(value: NavigableHNUser(id: comment.author)) {
                        Text("View User")
                    }
                    ShareLink("Share Comment", item: comment.postUrlString)
                } label: {
                    asButton {
                        Image(systemName: "ellipsis")
                            .rotationEffect(Angle(degrees: 90))
                    }
                }
                .menuStyle(.borderlessButton)
            }
        }
        .fontWeight(.semibold)
        .foregroundColor(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(isExpanded ? .clear : .gray.opacity(0.15))
        }
    }
    
    private func asButton<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxHeight: .infinity)
            .padding(5)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(buttonBackgroundColor.opacity(0.15))
            }
    }

    private var postOpIndicator: some View {
        Text("op")
            .padding(2)
            .font(.caption2.smallCaps())
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 3)
                    .foregroundColor(.orange)
            }
    }
}

private struct CommentBackgroundGeo: View {
    let topBuffer: CGFloat
    let commentId: Int
    let nextCommentId: Int?
    @Binding var scrollToCommentId: Int?

    var body: some View {
        GeometryReader { commentGeometry in
            let offset = commentGeometry.frame(in: .global).origin.y
            Color.clear
                .onChange(of: offset) { [offset] newOffset in
                    if offset < newOffset && offset > 1 && offset < 10 && scrollToCommentId != commentId {
                        scrollToCommentId = commentId
                    } else if offset > newOffset && newOffset < topBuffer && scrollToCommentId == commentId {
                        scrollToCommentId = nextCommentId
                    }
                }
        }
    }
}

private struct FaviconImage: View {
    let urlString: String?
    @State private var favicon: UIImage?
    
    var body: some View {
        ZStack {
            if let favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18)
                    .clipShape(Circle())
            }
        }
        .task {
            if let urlString, let url = URL(string: urlString) {
                favicon = await AsyncMetadataImage.fetchMetaImage(url: url, .favicon)
            }
        }
    }
}

private struct HeroImage: View {
    init(urlString: String? = nil, width: Double) {
        self.urlString = urlString
        self.width = width
        self._offset = State(initialValue: Double.random(in: -(width / 2) ... (width / 2)))
    }
    
    let urlString: String?
    let width: Double
    @State private var image: UIImage?
    
    @State private var offset: Double
    
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .frame(width: width * 0.7)
                    .blur(radius: 20)
                    .foregroundColor(.secondary)
                    .offset(x: offset, y: offset)
            }
        }
        .task {
            if let urlString, let url = URL(string: urlString) {
                image = await AsyncMetadataImage.fetchMetaImage(url: url, .preview)
            }
        }
    }
}

// struct HNPost_Previews: PreviewProvider {
//    static var previews: some View {
//        let preview = PostPreview(id: 37250821, author: "grogu88", type: Post.PostType.story, createdAt: 1692894294, title: "Build a chatbot with custom data sources, powered by LlamaIndex", linkedUrlString: "https://blog.streamlit.io/build-a-chatbot-with-custom-data-sources-powered-by-llamaindex/", postUrlString: buildPostUrl(nil, id: 37250821))
//        PostDetailScreen(preview: preview)
//    }
// }
