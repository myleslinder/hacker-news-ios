//
//  TabNavigationStack.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-05.
//

import SwiftUI

struct TabNavigationStack<Content: View>: View {
    @StateObject private var tabbb: Tab

    let id: TabSelection.TabId
    var content: () -> Content

    init(id: TabSelection.TabId, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.content = content
        self._tabbb = StateObject(wrappedValue: Tab(id: id))
    }
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack(path: $tabbb.path) {
                NavigationStackRoot {
                    content()
                        .environmentObject(tabbb)
                }
                }
            .safeAreaInset(edge: .bottom) {
                Rectangle()
                    .fill(Material.ultraThin)
                    .frame(height: geometry.safeAreaInsets.bottom)
                    .offset(y: geometry.safeAreaInsets.bottom)
            }
        }
    }
}

func postDetail(_ preview: PostPreview) -> some View {
    GeometryReader { geo in
        PostDetailScreen(preview: preview, containingGeometry: geo)
            .ignoresSafeArea(edges: .top)
    }
}

extension View {
    func withUserDestination() -> some View {
        self.navigationDestination(for: NavigableHNUser.self) { user in
            switch user.type {
            case .activity(let type):
                GeometryReader { geo in
                    UserActivityScreen(id: user.id, selectedPostType: type, containingGeometry: geo)
                        .ignoresSafeArea(edges: .top)
//                        .toolbarBackground(.hidden, for: .navigationBar)
                }
            case .user:
                UserScreen(id: user.id)
//                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}

func urlDestination(_ url: URL)  -> some View {
        GeometryReader { proxy in
            SFSafariViewWrapper(url: url)
                .padding(.top, -proxy.safeAreaInsets.top * 1.5)
        }
        .edgesIgnoringSafeArea([.bottom])
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
}

private struct NavigationStackRoot<Content: View>: View {
    @ViewBuilder let root: () -> Content
    var body: some View {
        root()
            .withUserDestination()
            .navigationDestination(for: URL.self) { url in
                urlDestination(url)
            }
            .navigationDestination(for: PostPreview.self) { preview in
               postDetail(preview)
            }
    }
}

// struct HNNavigationStack_Previews: PreviewProvider {
//    static var previews: some View {
//        let tabSelection = TabSelection(selection: .category)
//        TabNavigationStack(navigableTab: .constant(TabManager.Tab(navigableTab: .category, path: .init())), selectionsPublisher: tabManager.$selections) {
//            EmptyView()
//        }
//    }
// }
