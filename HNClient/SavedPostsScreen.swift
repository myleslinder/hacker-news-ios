//
//  SavedPostsScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-07-29.
//

import SwiftUI

struct SavedPostsScreen: TabContentRoot {
    @EnvironmentObject internal var tabbb: Tab
    @Environment(\.colorScheme) private var colorScheme
    // TODO: EXPENSIVE
    @JSONAppStorage(\.savedPosts) private var savedPosts
    // TODO: EXPENSIVE
    @JSONAppStorage(\.seenPosts) private var seenPosts

    let id: TabSelection.TabId
    let containingGeometry: GeometryProxy

    @State private var selectedPostType: Post.PostType = .story
    @State private var editMode: EditMode = .inactive

    private func collection(_ type: Post.PostType) -> Binding<[PostPreview]> {
        switch type {
        case .comment: return $savedPosts.comments
        case .story: return $savedPosts.stories
        }
    }

    private var emptyText: String {
        selectedPostType == .comment ? "No saved comments." : "No saved stories."
    }

    private var primaryForegroundStyle: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        TabView(selection: $selectedPostType) {
                List {
                    listHeader(id)
                    itemsList(collection(.story)) { item in
                        PostLinkLabel(seenPosts: seenPosts, savedPosts: savedPosts, result: item, indicatorStyle: .none)
                            .foregroundColor(.secondary)
                    }
                }
                .listStyle(.plain)
            
            .tag(Post.PostType.story)
                List {
                    listHeader(id)
                    itemsList(collection(.comment)) { item in
                        CommentListItem(title: item.title, author: item.author, createdAt: item.createdAt, htmlText: item.htmlText)
                    }
                }
                .listStyle(.plain)
            .tag(Post.PostType.comment)
        }
        .tabViewStyle(.page)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .padding(.top, -containingGeometry.safeAreaInsets.top)
        .safeAreaInset(edge: .top, content: {
            pageHeader

        })
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
    }
    
    private var pageHeader: some View {
        var actionButtons: some View {
            HStack(spacing: 12.5) {
                NavigationLink(value: ViewedPostHistory(posts: seenPosts)) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.orange, primaryForegroundStyle)
                }
                Image(systemName: "pencil")
                    .symbolVariant(editMode == .active ? .slash : .none)
                    .foregroundStyle(primaryForegroundStyle, .orange)
                    .onTapGesture {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
            }
            .font(.title3)
            .symbolRenderingMode(.palette)
        }
        return VStack(alignment: .leading) {
            HStack {
                Text("Saved Posts")
                    .screenTitle()
                    .foregroundColor(.orange)
                Spacer()
                actionButtons
            }
            .padding(.horizontal)
            .padding(.top, HNClientApp.Constants.topNavBarPadding)
            TabBar(selection: $selectedPostType) { type in
                Image(systemName: type.systemImage)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Material.ultraThin)
    }

    private func listHeader(_ id: TabSelection.TabId) -> some View {
        Text("")
            .id(id)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 20, trailing: 0))
            .listRowSeparator(.hidden)
    }

    private func itemsList<Content: View>(_ items: Binding<[PostPreview]>, @ViewBuilder content: @escaping (PostPreview) -> Content) -> some View {
        ForEach(items, editActions: [.all]) { item in
            let isFirstItem = items[0].wrappedValue.id == item.wrappedValue.id
            let navlink = ZStack(alignment: .leading) {
                NavigationLink(value: item.wrappedValue) {
                    EmptyView()
                }
                .opacity(0)
                content(item.wrappedValue)
            }
            if isFirstItem {
                navlink
                    .listRowSeparator(.hidden, edges: .top)
            } else {
                navlink
            }
        }
    }

  
}



// struct SavedPostsPage_Previews: PreviewProvider {
//    static var previews: some View {
//        SavedPostsPage()
//    }
// }
