//
//  UserActivityScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-07.
//

import SwiftUI

struct UserActivityScreen: View {
    @StateObject private var searchVm = AlgoliaSearch()

    let id: String
    @State var selectedPostType: Post.PostType
    let containingGeometry: GeometryProxy

    @State private var searchType: AlgoliaSearchType = .recent
    @State private var showLoadingIndicator = false

    private var commentResults: [CommentSearchResult]? { searchVm.commentResults }
    private var storyResults: [StorySearchResult]? { searchVm.storyResults }

    private func fetchUserActivities() async {
        await searchVm.search(AlgoliaSearchParam(searchType: searchType, tags: [.author_(username: id)]))
    }

    var body: some View {
        VStack {
            if showLoadingIndicator {
                list
                    .loading(searchVm.fetchStatus == .fetching)
            } else {
                list
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top, content: {
            TabBar(selection: $selectedPostType) { type in
                Image(systemName: type.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, containingGeometry.safeAreaInsets.top + HNClientApp.Constants.topNavBarPadding)
            .background(Material.ultraThin)

        })
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Activities")
                    .screenTitle()
            }
        }
        .toolbarTitleMenu {
            Section("Sort By") {
                Picker("Search Type", selection: $searchType) {
                    ForEach(AlgoliaSearchType.allCases, id: \.self) { searchType in
                        Label(searchType.rawValue, systemImage: searchType.systemImage)
                    }
                }
                .disabled(searchVm.results == nil || searchVm.results!.isEmpty)
            }
        }
        .onChange(of: searchType, perform: { _ in
            showLoadingIndicator = true
        })
        .task(id: searchType) {
            await fetchUserActivities()
        }
    }
    
    
    private var toolbarMenu: some View {
        Menu {
            Picker("Search Type", selection: $searchType) {
                ForEach(AlgoliaSearchType.allCases, id: \.self) { searchType in
                    Label(searchType.rawValue, systemImage: searchType.systemImage)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.accentColor, Color(uiColor: UIColor.quaternarySystemFill))
                .font(.title3)
        }
    }

    private var list: some View {
        Group {
            switch selectedPostType {
            case .story:
                PostList(storyResults) {
                    Text("")
                        .padding(.top, -containingGeometry.safeAreaInsets.top)
                }
                .padding(.top, -containingGeometry.safeAreaInsets.top)
                    .empty(storyResults?.isEmpty ?? false, "\(id) hasn't posted yet.")
                    .transition(.move(edge: .leading))
            case .comment:
                if let commentResults {
                    List(commentResults) { comment in
                        BubblingNavLink(value: PostPreview(from: comment)) {
                            CommentListItem(title: comment.title, author: comment.author, createdAt: comment.createdAt, htmlText: comment.$text)
                        }
                    }
                    .empty(commentResults.isEmpty, "\(id) hasn't made any comments yet.")
                    .transition(.move(edge: .trailing))
                }
            }
        }
    }

}

// struct UserActivityPage_Previews: PreviewProvider {
//    static var previews: some View {
//        UserActivityPage()
//    }
// }
