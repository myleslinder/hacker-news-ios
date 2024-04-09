//
//  HNClientApp.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-10.
//

import SwiftUI

class CustomBackButtonNavController: UIBarButtonItem, UIAppearanceContainer {
    override func backButtonBackgroundImage(for state: UIControl.State, barMetrics: UIBarMetrics) -> UIImage? {
        UIImage(systemName: "space")
    }
    override func setBackButtonBackgroundImage(_ backgroundImage: UIImage?, for state: UIControl.State, barMetrics: UIBarMetrics) {
        //
    }
}


@main
struct HNClientApp: App {
  
    @State var i = 0
    var body: some Scene {
        WindowGroup {
            AppScene()
        }
    }

    enum Constants {
        static let topNavBarPadding = 2.5
    }
}

struct AppScene: View {
    @StateObject private var tabSelection: TabSelection = .shared
    @StateObject private var sheetNavigation: SheetNavigation = .shared

    private var selectedTab: Binding<TabSelection.TabId> {
        Binding(
            get: { tabSelection.selections.current },
            set: { selection in
                tabSelection.updateSelections(current: selection)
            }
        )
    }

    var body: some View {
        TabView(selection: selectedTab) {
            ForEach(tabSelection.tabs) { tab in
                GeometryReader { geometry in
                    TabNavigationStack(id: tab.id) {
                        switch tab.id {
                        case .category:
                                StoryCategoryScreen(id: tab.id, containingGeometry: geometry)
                                    .toolbar(.hidden, for: .navigationBar)
                                    .ignoresSafeArea(edges: [.top, .bottom])
                        case .past:
                                PastStoriesScreen(id: tab.id, containingGeometry: geometry)
                                    .toolbar(.hidden, for: .navigationBar)
                                    .ignoresSafeArea(edges: [.top, .bottom])
                        case .search:
                                SearchScreen(id: tab.id, containingGeometry: geometry)
                                    .toolbar(.hidden, for: .navigationBar)
                                    .ignoresSafeArea(.container, edges: [.top, .bottom])
                        case .profile:
                            LoginSheet()
                        }
                    }
                }
                .coordinateSpace(name: tab.id)
                .tabItem {
                    Label {
                        Text(tab.id.label)
                    } icon: {
                        tab.id.image(isActive: tab.id == selectedTab.wrappedValue.id)
                    }
                }
                .tag(tab.id)
            }
            .toolbarBackground(.hidden, for: .tabBar)
        }
        .sheet(item: $sheetNavigation.sheetRootValue) {
            AppSheet(sheetRoot: $0)
        }
        .tint(.primary)
    }
}

private struct AppSheet: View {
    let sheetRoot: SheetNavigation.SheetRootItem<AnyHashable>
    var detents: Set<PresentationDetent> {
        switch sheetRoot.value.self {
        case is URL: return [.large]
        default: return [.medium]
        }
    }

    var body: some View {
        NavigationStack {
            switch sheetRoot.value {
            case let user as NavigableHNUser:
                UserScreen(id: user.id)
                    .toolbar(.hidden, for: .navigationBar)
                    .withUserDestination()
                    .presentationDetents([.medium])

            case let preview as PostPreview:
                postDetail(preview)
                    .withUserDestination()
            case let url as URL:
                urlDestination(url)
            default:
                EmptyView()
            }
        }
        .allowMainTabNavigation()
        .presentationDragIndicator(.hidden)
        .presentationDetents(detents)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.init(top: 0, leading: 0, bottom: 5, trailing: 5))
    }
}

// MARK: - Protocols & Extensions

protocol TabContentRoot: View {
    var id: TabSelection.TabId { get }
    var tabbb: Tab { get }
}

extension TabContentRoot {
    var tabManager: TabSelection { .shared }

    func assignTabTapAction(action: @escaping () -> Void) {
        tabbb.assignTapAction(for: id, action: action)
    }
}

/**
 .safeAreaInset(edge: .top) {
     Button {
         print("Asdasdasd")
     } label: {
         ZStack(alignment: .bottom) {
             Image(systemName: "menubar.rectangle")
                 .font(.subheadline)
                 .foregroundColor(.primary)

             Image(systemName: "arrow.up.right")
                 .padding(3)
                 .background(Circle().fill(Color.secondarySystemBackground))
                 .font(.caption2)
                 .offset(x: 7, y: -3)
         }
     }
 }
 */
