//
//  HistoryScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-02.
//

import SwiftUI


struct ViewedPostHistory: Hashable {
    let posts: [SeenPost]
}

struct HistoryScreen: View {
    // TODO: EXPENSIVE
//    private var seenPosts: [SeenPost]

    @StateObject private var searchVm = AlgoliaSearch()
    @StateObject private var postlistStorage: PostListStorage
    

    private let ids: [Int]
    let containingGeometry: GeometryProxy
    
    init(containingGeometry: GeometryProxy) {
        let storage = PostListStorage()
        self._postlistStorage = StateObject(wrappedValue: storage)
//        postlistStorage.seenPosts
//        self.seenPosts = seenPosts
        self.containingGeometry = containingGeometry
        self.ids = storage.seenPosts.map(\.id)
    }
    
    
    private var results: [StorySearchResult]? {
        if let searchResults = searchVm.results {
            let storyIdToResult = searchResults.reduce([Int: StorySearchResult]()) { mapped, result in
                switch result {
                case .story(let story):
                    var newResult = mapped
                    newResult[story.id] = story
                    return newResult
                default: break
                }
                return mapped
            }
            let orderedResults = postlistStorage.seenPosts.map { storyIdToResult[$0.id] }
            return orderedResults.compactMap { $0 }
        }
        return nil
    }


    @State private var scrollOffset: CGFloat = 0
    @State private var initialScrollOffset: CGFloat?
    
    // TODO: consider supporting comments here from view thread
    var body: some View {
//        VStack{
//            ScrollView {
//                Rectangle()
//                    .frame(height: 500)
//                GeometryReader { geometry in
//                    Rectangle()
//                        .frame(height: 500)
//                        .onChange(of: geometry.frame(in: .global).origin.y) { newValue in
//                            if initialScrollOffset == nil {
//                                initialScrollOffset = newValue
//                            }
//                            scrollOffset = newValue - (initialScrollOffset ?? 0)
//                            print(scrollOffset)
//                        }
//                }
//            }
//            DesinationNavBarView(scrollDistance: scrollOffset)
//                .frame(width: 0, height: 0)
//
//        }
        VStack {
            RootNavBarView()
                .frame(width: 0, height: 0)
                switch searchVm.fetchStatus {
                case .idle, .fetching:
                    if let results {
                        PostList(results, indicatorStyle: .seenAndSaved(opacity: false)) {
                            Text("")
                                .padding(.top, -containingGeometry.safeAreaInsets.top)
                        }
                        .padding(.top, -containingGeometry.safeAreaInsets.top)
                        .listStyle(.plain)
                        .empty(results.isEmpty, "No viewed posts yet.")
                    }
                case .failed(reason: let reason): SomethingWentWrong(errorReason: reason)
                }
        }
        .loading(searchVm.fetchStatus == .fetching)
        .safeAreaInset(edge: .top) {
            Rectangle()
                .fill(Material.ultraThin)
                .frame(height: containingGeometry.safeAreaInsets.top)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("History")
                    .screenTitle()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Text("Only the last 100 viewed stories are available")
                } label: {
                    Image(systemName: "info.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.primary)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await fetchHistory()
        }
        .task {
            if searchVm.results == nil {
                await fetchHistory()
            }
        }
    }
    
    private func fetchHistory() async {
        if ids.count != 0 {        
            let storyTags: [AlgoliaSearchParam.Tag] = ids[..<min(100, ids.finalIndex)].map { .story_(id: String($0)) }
            await searchVm.search(.init(tagGroups: [.and([.story]), .or(storyTags)]))
        }
        
    }

}

// struct HistoryPage_Previews: PreviewProvider {
//    static var previews: some View {
//        HistoryScreen()
//    }
// }
