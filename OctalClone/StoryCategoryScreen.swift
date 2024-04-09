//
//  StoryCategoryScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-07-23.
//

import SwiftUI

private struct Subtitle: View, Equatable {
    var body: some View {
        let (dow, day, month, _) = formatDate()
        return Text("\(dow), \(month) \(day)")
    }
}

struct StoryCategoryScreen: TabContentRoot {
    @EnvironmentObject internal var tabbb: Tab

    @StateObject private var postListVm = HackerNewsCategory()

    let id: TabSelection.TabId
    let containingGeometry: GeometryProxy

    @State private var selections = Selections()
    @State private var showSheet = false

    private var categoryOrderResults: HackerNewsCategory.CategoryOrderResultsMap { postListVm.categoryOrderResults }
    private var resultsForSelections: [StorySearchResult]? { categoryOrderResults[selections.storyCategory]?[selections.storyOrder] }
    private var safeAreaInsetTop: CGFloat { containingGeometry.safeAreaInsets.top }
    private let scaleFactor = 0.85

    private var loading: Bool { postListVm.fetchStatus == .fetching }
    @State private var delayedLoading: Bool = false
    var headerTextIsCategoryColor: Bool { !delayedLoading }
    func duration(loading: Bool) {
        if loading {
            delayedLoading = true
        } else {
            if showSheet {
                delayedLoading = false
                return
            }
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                delayedLoading = false
            }
        }
    }

    // TODO: BUG HERE with List failed to visit cell content, returning an empty cell. so it messed up loading background
    var body: some View {
        GeometryReader { geometry in
            screenBackground(loading: loading, geometry: geometry)
                .onChange(of: loading, perform: duration)
            Group {
                switch postListVm.fetchStatus {
                case .idle, .fetching:
                    PostList(resultsForSelections ?? []) {
                        PullToLoad(loading: loading, color: selections.storyCategory.color) {
                            await postListVm.fetch(category: selections.storyCategory, order: selections.storyOrder)
                        }
                        .id(id)
                        .padding(.top, -safeAreaInsetTop)
                        .opacity(showSheet ? 0 : 1)
                    }
                    .listStyle(.plain)
                    .offset(y: -safeAreaInsetTop)
                    .background(Color.systemBackground)
                case .failed(reason: let reason):
                    SomethingWentWrong(errorReason: reason)
                        .padding(.top, safeAreaInsetTop)
                }
            }
            .safeAreaInset(edge: .top) {
                ScreenHeader(selections: selections, showSheet: $showSheet, topPadding: safeAreaInsetTop + HNClientApp.Constants.topNavBarPadding, headerTextIsCategoryColor: headerTextIsCategoryColor)
            }
            .scaleEffect(showSheet ? scaleFactor : 1)
            .roundCorners { mask in
                mask
                    .scaleEffect(showSheet ? scaleFactor : 1)
            }
        }

        .sheet(isPresented: $showSheet) {
            AnimatingSheetContent(isPresented: $showSheet, containingGeometry: containingGeometry, globalFrameName: id) { _ in
                SelectionSheet(selections: $selections)
                    .padding()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .navigationTitle(selections.storyCategory.label)
        .onChange(of: resultsForSelections) { newResults in
            if let newResults, !newResults.isEmpty {
                withAnimation {
                    showSheet = false
                }
            }
        }
        .onAppear {
            assignTabTapAction {
                withAnimation {
                    showSheet = true
                }
            }
        }
        .task(id: selections) {
            if resultsForSelections == nil {
                await postListVm.fetch(category: selections.storyCategory, order: selections.storyOrder)
            }
        }
    }

    @ViewBuilder
    private func screenBackground(loading: Bool, geometry: GeometryProxy) -> some View {
        let width = geometry.size.width + 200
        let heightBuffer = 100.0
        if showSheet {
            selections.storyCategory.color
                .overlay {
                    Rectangle()
                        .fill(Color.systemBackground.opacity(0.2))
                        .rotationEffect(Angle(degrees: 8))
                        .offset(x: loading ? width : -width)
                        .frame(width: width, height: geometry.size.height + heightBuffer)
                        .animation(
                            .linear(duration: loading ? 2.2 : 0).repeatForever(autoreverses: false),
                            value: loading
                        )
                        .blur(radius: 10)
                }
        } else {
            Color.systemBackground
        }
    }
}

// TODO: change params, especitally header text is, also no need for selections just foreground color
private struct ScreenHeader: View {
    let selections: Selections
    @Binding var showSheet: Bool
    let topPadding: Double
    let headerTextIsCategoryColor: Bool

    var body: some View {
        VStack {
            let foregroundColor: Color = headerTextIsCategoryColor || showSheet ? selections.storyCategory.color : Color.systemBackground
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(selections.storyCategory.label)
                        .screenTitle()
                        .animation(.easeInOut(duration: headerTextIsCategoryColor ? 0 : 0.75), value: headerTextIsCategoryColor)
                    Image(systemName: "chevron.down")
                        .font(.callout)
                        .rotationEffect(Angle(degrees: showSheet ? -180 : 0), anchor: .center)
                        .animation(.easeInOut, value: showSheet)
                }
                .foregroundColor(foregroundColor)

                Subtitle()
                    .equatable()
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .opacity(0.9)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .bottom])
        }
        .padding(.init(top: topPadding, leading: 0, bottom: -2, trailing: 0))
        .background(Material.ultraThin, in: Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .onTapGesture {
            withAnimation {
                showSheet = true
            }
        }
    }
}

private struct SelectionSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selections: Selections

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            selectionsSheetSectionHeader("Story Order")
            Grid {
                GridRow {
                    ForEach(HackerNewsAPI.StoryOrder.allCases, id: \.self, content: storyOrderGridItem)
                }
            }
            selectionsSheetSectionHeader("Story Category")
            LazyVGrid(columns: [GridItem(), GridItem()]) {
                ForEach(HackerNewsAPI.StoryCategory.allCases, id: \.self, content: storyCategoryGridItem)
            }
        }
        .buttonStyle(.borderedProminent)
    }

    private func selectionsSheetSectionHeader(_ title: String) -> some View {
        Text(title)
            .fontWeight(.medium)
            .font(.caption.smallCaps())
            .foregroundColor(.gray)
    }

    @ViewBuilder
    private func storyOrderGridItem(for storyOrder: HackerNewsAPI.StoryOrder) -> some View {
        let colorSchemeTint = colorScheme == .dark ? Color.tertiarySystemBackground : .white
        let tint = selections.storyOrder == storyOrder ? selections.storyCategory.color : colorSchemeTint
        let foregroundColor: Color = selections.storyOrder == storyOrder ? .white : .primary
        Button {
            selections.storyOrder = storyOrder
        } label: {
            HStack {
                Image(systemName: storyOrder.systemImage)
                Text(storyOrder.label)
                    .fontWeight(.medium)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 5)
            .foregroundColor(foregroundColor)
        }
        .tint(tint)
    }

    @ViewBuilder
    private func storyCategoryGridItem(for storyCategory: HackerNewsAPI.StoryCategory) -> some View {
        let colorSchemeTint = colorScheme == .dark ? Color.tertiarySystemBackground : .white
        let tint = selections.storyCategory == storyCategory ? selections.storyCategory.color : colorSchemeTint
        let foregroundStylePrimary: Color = selections.storyCategory == storyCategory ? storyCategory.color : .white
        let foregroundStyleSecondary: Color = selections.storyCategory == storyCategory ? .white : storyCategory.color
        let foregroundColor: Color = selections.storyCategory == storyCategory ? .white : .primary
        Button {
            withAnimation {
                selections.storyCategory = storyCategory
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: storyCategory.systemImage)
                    .font(.title)
                    .foregroundStyle(foregroundStylePrimary, foregroundStyleSecondary)
                Text(storyCategory.label)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(foregroundColor)
            }
            .padding(.vertical, 5)
        }
        .tint(tint)
    }
}

private struct PullToLoad: View {
    let loading: Bool
    let color: Color
    let onRangeEnd: () async -> Void

    let buffer: Double = 40
    let indicatorSize: Double = 30
    let indicatorBorderWidth: Double = 2.5

    var foregroundColor: Color {
        loading ? Color.systemBackground : color
    }

    var body: some View {
        GeometryReader { proxy in
            let y = proxy.frame(in: .named("ListView")).origin.y
            let rangeEnd = proxy.size.height + buffer
            VStack {
                ZStack(alignment: .center) {
                    Circle()
                        .frame(width: indicatorSize, height: indicatorSize)
                        .foregroundColor(foregroundColor) // TODO: issue
                        .background {
                            color.opacity(0.3).colorMultiply(color)
                                .frame(width: indicatorSize + indicatorBorderWidth, height: indicatorSize + indicatorBorderWidth)
                                .clipShape(Circle())
//                                .opacity(loading ? 0 : 1)
                        }
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .foregroundColor(.white)
//                        .rotationEffect(Angle(degrees: y * 6), anchor: .center)
//                        .animation(.linear, value: y > buffer)
                }
                .offset(y: -40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .opacity((y - 25) / buffer)
//                .animation(.easeInOut, value: y > buffer)
                .onChange(of: y, perform: { [y] newValue in
                    let range = (rangeEnd - 4) ... (rangeEnd + 4)
                    if !loading, range.contains(newValue), y < newValue {
                        withHapticFeedback(.success) {
                            Task {
                                await onRangeEnd()
                            }
                        }
                    }
                })
            }
            .overlay {
                LoadingBackground(color: color, loading: loading, offset: y)
            }
        }
    }

    private struct LoadingBackground: View {
        let color: Color
        let loading: Bool
        let offset: CGFloat

        var body: some View {
            GeometryReader { proxy in
                HStack {
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundColor(color)
                        .frame(width: proxy.size.width, height: loading ? nil : 1, alignment: .bottom)
                        .animation(.easeInOut(duration: 0.5), value: loading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .overlay {
                    Rectangle()
                        .fill(Color.systemBackground.opacity(0.2))
                        .frame(width: proxy.size.width, height: proxy.size.width - 50)
                        .rotationEffect(Angle(degrees: -75))
                        .offset(x: loading ? proxy.size.width : -proxy.size.width)
                        .opacity(loading ? 1 : 0)
                        .animation(.linear(duration: loading ? 2 : 0).repeatForever(autoreverses: false), value: loading)
                        .blur(radius: 10)
                }
            }
//            .frame(height: 400 + offset, alignment: .bottom)
        }
    }
}

private struct Selections: Equatable {
    var storyCategory: HackerNewsAPI.StoryCategory = .top
    var storyOrder: HackerNewsAPI.StoryOrder = .original
}

// struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        StoryCategoryPage()
//    }
// }
