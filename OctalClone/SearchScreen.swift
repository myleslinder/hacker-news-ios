//
//  SearchScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-08.
//

import SwiftUI

struct SearchScreen: TabContentRoot {
    typealias Tag = AlgoliaSearchParam.Tag
    typealias BoundOptionalTag = Binding<Tag?>
    @EnvironmentObject internal var tabbb: Tab
    @JSONAppStorage(\.savedPosts) private var savedPosts
    @JSONAppStorage(\.seenPosts) private var seenPosts
    @StateObject private var searchVm = AlgoliaSearch()

    let id: TabSelection.TabId
    let containingGeometry: GeometryProxy

    private var results: [SearchResult]? { searchVm.results }

    @State var searchText: String = ""
    @State private var tokens: [Tag] = []
    @State private var searchType: AlgoliaSearchParam.SearchType = .recent

    @State private var isSearching = false
    @State private var beforeDate = Date()
    @State private var afterDate: Date = getDateOffset(1)!
    @State private var useBeforeDate = false
    @State private var useAfterDate = false

    private var nonAuthorTokens: [Tag] { tokens.filter(!, \.isIdType) }

    private var isFrontPageOnly: Binding<Bool> {
        Binding { tokens.contains(.front_page) }
            set: { _ in tokens.toggle(.front_page) }
    }

    private var pageTypeSelection: Binding<AlgoliaSearchParam.Tag?> {
        Binding {
            tokens.first(where: { $0.isPageType })
        } set: { selection in
            tokens = tokens.filter(!, \.isPageType)
            if let selection {
                tokens.append(selection)
            }
        }
    }

    private var contentTypeSelection: Binding<AlgoliaSearchParam.Tag?> {
        Binding {
            tokens.first(where: { $0.isContentType })
        } set: { selection in
            tokens = tokens.filter(!, \.isContentType)
            if let selection {
                tokens.append(selection)
            }
        }
    }
    
    @FocusState var searchFieldFocusState
    @State private var sss: Bool = false

    var body: some View {
        GeometryReader { geometry in
            
            ZStack(alignment: .bottom) {
                ZStack(alignment: .top) {
                    Color.systemBackground // Ensure no scale background shows through
                        .onAppear {
                            searchText = TabSelection.shared.payloads[id]?.payload ?? ""
                        }
                    VStack {
                        SearchedView(internalIsSearching: $isSearching, searchType: $searchType, fetchStatus: searchVm.fetchStatus, isFrontPageOnly: isFrontPageOnly, contentTypeSelection: contentTypeSelection, pageTypeSelection: pageTypeSelection, results: results, containingGeometry: containingGeometry) { results in
                            List {
                                Rectangle()
                                    .fill(Color.systemBackground)
                                    .frame(height: containingGeometry.safeAreaInsets.top * 2 + 35)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                ForEach(Array(results.enumerated()), id: \.element) { index, item in
                                    listRowBody(item: item)
                                        .optionalId(index == 0 ? id : nil)
                                }
                            }
                            .listStyle(.plain)
                            .transition(.opacity)
                            .padding(.top, -containingGeometry.safeAreaInsets.top)
                        }
                        .searchable(text: $searchText, tokens: $tokens, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search stories or comments") { token in
                            switch token {
                            case .author_: Text(token.label)
                            default: Label(token.label, systemImage: token.systemImage) // EmptyView()
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .padding(.top, containingGeometry.safeAreaInsets.top + 2.5)
                    VStack {
                        Text("Search")
                            .screenTitle()
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading)
                    }
                    .padding(.top, containingGeometry.safeAreaInsets.top + 2.5)
                    .background(Material.ultraThin)
                    .sheet(isPresented: $isSearching) {
                        FilterSheet(
                            tokens: $tokens,
                            searchText: $searchText,
                            isPresented: $isSearching,
                            searchType: $searchType,
                            isFrontPageOnly: isFrontPageOnly,
                            contentTypeSelection: contentTypeSelection,
                            pageTypeSelection: pageTypeSelection,
                            afterDate: $afterDate,
                            beforeDate: $beforeDate,
                            useBeforeDate: $useBeforeDate,
                            useAfterDate: $useAfterDate,
                            containingGeometry: containingGeometry,
                            globalFrameName: id)
                    }
                }
                VStack {
                    ZStack(alignment: .bottom) {
                        if sss {
                            VStack {
                                Capsule()
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, height: 5)
                                    .padding(.vertical, 5)
                                FilterSheet(
                                    tokens: $tokens,
                                    searchText: $searchText,
                                    isPresented: $isSearching,
                                    searchType: $searchType,
                                    isFrontPageOnly: isFrontPageOnly,
                                    contentTypeSelection: contentTypeSelection,
                                    pageTypeSelection: pageTypeSelection,
                                    afterDate: $afterDate,
                                    beforeDate: $beforeDate,
                                    useBeforeDate: $useBeforeDate,
                                    useAfterDate: $useAfterDate,
                                    containingGeometry: containingGeometry,
                                    globalFrameName: id)
                                .border(.red)
                            }
                          
                            .transition(.move(edge: .bottom).animation(.linear.delay(2)))
//                            .offset(y: searchFieldFocusState == true ? 0 : 400)
//                            .animation(.linear, value: searchFieldFocusState)
                            .background(Color.secondarySystemFill)
                        }
                        SearchInput(searchText: $searchText, searchFieldFocusState: _searchFieldFocusState)
                            .onChange(of: searchFieldFocusState, perform: { v in
                                withAnimation {
                                    sss = v
                                }
                            })
                    }
                    .background(Color.systemBackground)
                    .frame(height: containingGeometry.size.height + containingGeometry.safeAreaInsets.top, alignment: .bottom)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .background(Color.lightGray)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchText) { str in
            handleAuthorToken(str)
        }
        .onAppear {
            assignTabTapAction {
                withAnimation {
                    isSearching = true
                }
            }
        }
        .onSubmit(of: .text) {
            print("SDSDSD")
            Task {
                await search()
            }
//            withAnimation {
//                isSearching = false
//            }
        }
        .task(id: isSearching) {
            let query = buildSearchQuery()
            if let previousQuery = searchVm.query, previousQuery.path != query.path || previousQuery.queryItems.compactMap({ $0.value }) != query.queryItems.compactMap({ $0.value }), !isSearching {
                await search()
            } else if searchVm.query == nil {
                await search()
            }
        }
    }

    private func listRowBody(item: SearchResult) -> some View {
        Group {
            switch item {
            case .comment(let comment):
                let preview = PostPreview(from: comment)
                NavigationLink(value: preview) {
                    CommentListItem(title: comment.title, author: comment.author, createdAt: comment.createdAt, htmlText: comment.$text)
                }
            case .story(let story):
                let preview = PostPreview(from: story)
                NavigationLink(value: preview) {
                    PostLinkLabel(seenPosts: seenPosts, savedPosts: savedPosts, result: preview)
                }
            }
        }
    }

    private func handleAuthorToken(_ text: String) {
        if text.hasSuffix(" ") {
            var newText = text
            let authorTokenRegex = /@\w+/
            for range in text.ranges(of: authorTokenRegex) {
                var username = newText[range]
                username = username.dropFirst()
                if !tokens.filter(\.isIdType).contains(where: { $0.id == "author_\(username)" }) {
                    tokens.append(.author_(username: String(username)))
                }
                newText.removeSubrange(range)
                newText.removeLast()
            }
            searchText = newText
        }
    }

    private func buildSearchQuery() -> AlgoliaSearchParam {
        .init(searchType: searchType, query: searchText, tagGroups: buildTagGroups(), numericFilter: numericFilters)
    }

    private func search() async {
        if !(searchText.isEmpty && tokens.filter(\.isIdType).isEmpty) {
            await searchVm.search(buildSearchQuery())
        }
    }

    private func buildTagGroups() -> [AlgoliaSearchParam.TagGroup] {
        var authorTags: [AlgoliaSearchParam.Tag] = []
        var otherTags: [AlgoliaSearchParam.Tag] = []
        for token in tokens {
            switch token {
            case .author_: authorTags.append(token)
            default: otherTags.append(token)
            }
        }
        return [.and(otherTags), authorTags.count == 1 ? .and(authorTags) : .or(authorTags)]
    }

    private var numericFilters: [AlgoliaSearchParam.NumericFilter] {
        var filters = [AlgoliaSearchParam.NumericFilter]()
        if useBeforeDate {
            filters.append(.createdAt(.lessThan(equal: true), unixTime(date: beforeDate, 0)!))
        }
        if useAfterDate {
            filters.append(.createdAt(.greaterThan(equal: true), unixTime(date: afterDate, 0)!))
        }
        return filters
    }
}

private struct SearchedView<Content: View>: View {
    @Binding var internalIsSearching: Bool

    @Binding var searchType: AlgoliaSearchParam.SearchType
    let fetchStatus: AlgoliaAPI.FetchStatus
    @Binding var isFrontPageOnly: Bool
    @Binding var contentTypeSelection: AlgoliaSearchParam.Tag?
    @Binding var pageTypeSelection: AlgoliaSearchParam.Tag?
    let results: [SearchResult]?
    let containingGeometry: GeometryProxy
    @ViewBuilder var resultsList: ([SearchResult]) -> Content

    var body: some View {
        GeometryReader { geometry in
            let loadingList = List {
                Rectangle()
                    .fill(Color.systemBackground)
                    .frame(height: containingGeometry.safeAreaInsets.top)
                    .padding(.top, -containingGeometry.safeAreaInsets.top)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                ForEach(0 ..< 10) { i in
                    LoadingFrame(geometry: geometry)
                        .listRowSeparator(i == 0 ? .hidden : .visible)
                }
            }.padding(.top, -containingGeometry.safeAreaInsets.top)

                .listStyle(.plain)
            VStack {
                Group {
                    switch fetchStatus {
                    case .idle:
                        if let results {
                            if results.isEmpty {
                                NoSearchResults()
                                    .transition(.opacity)
                            } else {
                                resultsList(results)
                                    .transition(.opacity)
                            }
                        } else {
                            ScrollView {
                                EmptySearch()
                                    .padding(.top, 100)
                            }
                            .transition(.opacity)
                        }
                    case .fetching:
                        loadingList
                    case .failed(reason: let reason):
                        SomethingWentWrong(errorReason: reason)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct FilterSheet<T: Hashable>: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var tokens: [AlgoliaSearchParam.Tag]
    @Binding var searchText: String
    @Binding var isPresented: Bool
    @Binding var searchType: AlgoliaSearchType
    // TODO: fix me
    private var st: Binding<AlgoliaSearchType?> {
        Binding {
            searchType
        } set: { v in
            searchType = v ?? .recent
        }
    }

    @Binding var isFrontPageOnly: Bool
    @Binding var contentTypeSelection: AlgoliaSearchParam.Tag?
    @Binding var pageTypeSelection: AlgoliaSearchParam.Tag?
    @Binding var afterDate: Date
    @Binding var beforeDate: Date
    @Binding var useBeforeDate: Bool
    @Binding var useAfterDate: Bool

    let containingGeometry: GeometryProxy
    let globalFrameName: T

    @State private var isEditingAfterDate = false
    @State private var isEditingBeforeDate = false

    var body: some View {
//        AnimatingSheetContent(isPresented: $isPresented, containingGeometry: containingGeometry, globalFrameName: globalFrameName) { _ in
//        }
        Grid(alignment: .top, verticalSpacing: 10) {
            GridRow {
                VStack(alignment: .leading) {
                    SectionHeader(title: "Sort Order")
                    FilterSheetTopItems(selection: st, items: AlgoliaSearchType.allCases)
                }
            }
            .padding(.horizontal)
            GridRow {
                VStack(alignment: .leading) {
                    SectionHeader(title: "Content Type")
                    FilterSheetTopItems(selection: $contentTypeSelection, items: AlgoliaSearchParam.Tag.contentTypeCases)
                }
            }
            .padding(.horizontal)
            GridRow {
                VStack(alignment: .leading) {
                    SectionHeader(title: "Page Type")
                    FilterSheetTopItems(selection: $pageTypeSelection, items: AlgoliaSearchParam.Tag.pageTypeCases)
                }
            }
            .padding(.horizontal)
            GridRow {
                VStack(alignment: .leading) {
                    Grid {
                        GridRow {
                            VStack(alignment: .leading) {
                                SectionHeader(title: "After Date")
                                datePickerButton(afterDate, useDate: useAfterDate) {
                                    isEditingAfterDate = true
                                }
                                .popover(isPresented: $isEditingAfterDate) {
                                    datePickerPopover($afterDate, "After Date")
                                        .onChange(of: afterDate) { newAfterDate in
                                            if beforeDate <= newAfterDate && useBeforeDate {
                                                beforeDate = getDateOffset(date: newAfterDate, 1)!
                                            }
                                            useAfterDate = true
                                            withAnimation {
                                                isEditingAfterDate = false
                                            }
                                        }
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                SectionHeader(title: "Before Date")
                                datePickerButton(beforeDate, useDate: useBeforeDate) {
                                    isEditingBeforeDate = true
                                }
                                .popover(isPresented: $isEditingBeforeDate) {
                                    datePickerPopover($beforeDate, "Before Date")
                                        .onChange(of: beforeDate) { [beforeDate] newBeforeDate in
                                            if afterDate >= newBeforeDate && useAfterDate {
                                                afterDate = getDateOffset(date: newBeforeDate, 1)!
                                            }
                                            if beforeDate != Date() {
                                                useBeforeDate = true
                                                withAnimation {
                                                    isEditingBeforeDate = false
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            GridRow {
                VStack {
                    Spacer()
                    VStack(alignment: .leading) {
                        if tokens.isEmpty {
                            HStack {
                                Label("Type @name to add an author filter", systemImage: "info.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                                    .padding([.vertical, .horizontal], 5)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .background(Capsule(style: .circular).fill(Color.tertiarySystemFill))
                            .font(.callout)
                        } else {
//                            ScrollView(.horizontal, showsIndicators: false) {
//                                HStack {
//                                    ForEach(tokens.filter(\.isIdType)) { tag in
//                                        Button {
//                                            tokens = tokens.filter(\.id, !=, tag.id)
//                                        } label: {
//                                            Label(tag.id.split(separator: "_")[1], systemImage: "person")
//                                                .frame(maxWidth: .infinity, alignment: .leading)
//                                                .lineLimit(1)
//                                                .fontWeight(.medium)
//                                        }
//                                        .buttonStyle(.borderedProminent)
//                                        .foregroundColor(.primary)
//                                        .tint(colorScheme == .dark ? Color.tertiarySystemBackground : .white)
//                                    }
//                                }
//                                .frame(maxWidth: .infinity)
//                            }
//                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
//                    if !(isEditingAfterDate || isEditingBeforeDate) {
//                        SearchInput(searchText: $searchText)
//                    }
                }
            }
            .hidden()
        }
        .frame(maxHeight: 300)
//        .padding(.top)
////        .presentationDetents([.medium, .large])
////        .presentationDragIndicator(.visible)
//        .ignoresSafeArea(.container, edges: .bottom)
    }

    func datePickerButton(_ date: Date, useDate: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        }
        label: {
            ZStack {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    let dateComponents = formatDate(date)
                    Text(useDate ? "\(dateComponents.month) \(dateComponents.day), \(String(dateComponents.year))" : "Anytime")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fontWeight(.medium)
                .font(.callout)
                .padding(.vertical, 5)
                .foregroundColor(.primary)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.systemBackground)
    }

    func datePickerPopover(_ selection: Binding<Date>, _ title: String) -> some View {
        DatePicker(title, selection: selection, in: ...Date(), displayedComponents: [.date])
            .datePickerStyle(.graphical)
            .tint(.primary)
            .frame(width: containingGeometry.size.width - 40) // Bugfix for AutoLayout-Issue
    }

    struct SectionHeader: View {
        let title: String

        var body: some View {
            Text(title)
                .fontWeight(.medium)
                .font(.caption.smallCaps())
                .foregroundColor(.gray)
        }
    }
}

struct SearchInput: View {
    @Binding var searchText: String

    @FocusState var searchFieldFocusState

    var body: some View {
//
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.secondaryLabel)
                TextField("Search for stories or comments...", text: $searchText)
                    .focused($searchFieldFocusState)
                    .submitLabel(.search)
    //                .onSubmit { searchFieldFocusState = true }
    //                .submitScope(searchText.count < 3)
                Image(systemName: "x.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.secondaryLabel)
                    .onTapGesture {
                        searchText = ""
                        searchFieldFocusState = true
                    }
                    .opacity(searchText.isEmpty ? 0 : 1)
                    .scaleEffect(0.9)
            }
            .font(.callout)
            .padding()
            .background(Color.secondarySystemFill)
    }
}

struct FilterSheetTopItemsColumn<T: ChangeMe>: View {
    @Environment(\.colorScheme) private var colorScheme
    let tag: T
    @Binding var selection: T?

    var body: some View {
        Button {
            if selection == tag {
                selection = nil
            } else {
                selection = tag
            }
        } label: {
            HStack {
                Image(systemName: tag.systemImage)
                Text(tag.label)
                    .fontWeight(.medium)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 5)
            .foregroundColor(selection == tag ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
        .tint(selection == tag ? .orange : (colorScheme == .dark ? Color.tertiarySystemBackground : .white))
    }
}

struct FilterSheetTopItems<T: ChangeMe>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: T?
    let items: [T]

    var body: some View {
        Grid {
            GridRow {
                ForEach(items, id: \.self) { tag in
                    FilterSheetTopItemsColumn(tag: tag, selection: $selection)
                }
            }
        }
    }
}

//
// struct SearchPage_Previews: PreviewProvider {
//    static var previews: some View {
//        SearchScreen()
//    }
// }
