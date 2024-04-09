//
//  PastStoriesScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-13.
//

import SwiftUI

struct PastStoriesScreen: TabContentRoot {
    init(id: TabSelection.TabId, containingGeometry: GeometryProxy) {
        self.id = id
        self.containingGeometry = containingGeometry
        let options = PastStoriesScreen.createDays(getDateOffset(4)!)
        var newOpt = [PastDay(offset: -1, date: getDateOffset(-1)!)]
        newOpt.append(contentsOf: options)
        newOpt.append(PastDay(offset: 8, date: getDateOffset(8)!))
        self._options = State(initialValue: newOpt)
        self._selectedDay = State(initialValue: newOpt[2])
    }

    @EnvironmentObject internal var tabbb: Tab
    @StateObject private var searchVm = AlgoliaSearch()

    let id: TabSelection.TabId
    let containingGeometry: GeometryProxy

    // MARK: - State

    @State private var selectedCategory: AlgoliaSearchParam.Tag = .story
    @State private var pageSwipeDirection: Edge = .leading
    @State private var dayCategoryResults: [PastDay: [AlgoliaSearchParam.Tag: [StorySearchResult]]] = [:]
    @State private var listHeaderOffset: CGFloat = .zero

    @State private var selectedDay: PastDay
    @State private var options: [PastDay]

    @State private var showDatePicker = false

    private var dateBinding: Binding<Date> {
        Binding(get: { selectedDay.date },
                set: updateDayForDate)
    }

    @Namespace private var dateCircleNamespace
    @State private var draggedXOffset: CGFloat = .zero
    @State private var cursorOffset: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
                PostListCarousel(options.reversed(), fetchStatus: searchVm.fetchStatus, pageType: $selectedDay, titleYOffset: $listHeaderOffset, pageSwipeDirection: $pageSwipeDirection, wrap: false, containingGeometry: containingGeometry, draggedXOffset: $draggedXOffset) { _ in
                    ForEach(options, id: \.self) { day in
                        if day == selectedDay {
                            PostList(dayCategoryResults[day]?[selectedCategory]) {
                                Text("")
                                    .id(id)
                            }
                            .listStyle(.plain)
                            .transition(.push(from: pageSwipeDirection == .leading ? .trailing : .leading))
                        }
                    }
                    .padding(.top, -containingGeometry.safeAreaInsets.top)
                    .background(Color(uiColor: UIColor.systemBackground))
                }
            utilities: {
                EmptyView()
            }
            draggableItem: {
                OverlayButton("calendar", dimension: 40, offset: CGSize(width: 0, height: 0))
            }
            
            .safeAreaInset(edge: .top) {
                screenHeader
            }
            .scaleEffect(showDatePicker ? 0.85 : 1)
            .mask {
                RoundedRectangle(cornerRadius: 30)
                    .frame(height: max(containingGeometry.size.height + containingGeometry.safeAreaInsets.top + containingGeometry.safeAreaInsets.bottom + geometry.safeAreaInsets.top, 10), alignment: .top)
                    .scaleEffect(showDatePicker ? 0.85 : 1)
            }
            .animation(.easeInOut, value: showDatePicker)
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet(containingGeometry)
            }
            .navigationTitle("Past Stories")
            .task(id: selectedCategory) {
                if dayCategoryResults[selectedDay]?[selectedCategory] == nil {
                    await searchVm.search(
                        .init(searchType: .best, tags: [.story, selectedCategory], numericFilter: numericFilters)
                    )
                }
            }
            .task(id: selectedDay) {
                await handleDayChange(selectedDay)
            }
        }
        .onReceive(searchVm.$results, perform: updateCategoryResults)
        .onAppear {
            assignTabTapAction {
                withAnimation {
                    showDatePicker = true
                }
            }
        }
    }

    var screenHeader: some View {
        let reversed = options.reversed()
        let end = reversed.count > 7 ? reversed.index(before: reversed.finalIndex) : reversed.index(reversed.startIndex, offsetBy: 6)
        let start = reversed.count > 7 ? reversed.index(after: reversed.startIndex) : reversed.startIndex
        let range = reversed[start...end]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Button {
                    withAnimation {
                        showDatePicker = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(selectedDay.label)
                            .screenTitle()

                        Image(systemName: "chevron.down")
                            .font(.callout)
                            .rotationEffect(Angle(degrees: showDatePicker ? -180 : 0), anchor: .center)
                            .animation(.easeInOut, value: showDatePicker)
                        Spacer()
//                        Label(selectedCategory.label, systemImage: selectedCategory.systemImage)
//                            .font(.callout)
//                            .foregroundColor(.orange.opacity(0.7))
                    }
                    .foregroundColor(.orange)
                }
            }
            Grid {
                GridRow {
                    ForEach(range) { option in
                        DaySelector(option: option, selectedDay: $selectedDay, dateCircleNamespace: dateCircleNamespace)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 5)
        }
        .padding(.horizontal)
        .padding(.top, containingGeometry.safeAreaInsets.top + 2.5)
        .background(Material.ultraThin)
    }

    // MARK: - Utilities Menu

    private var utilities: some View {
        Button {
            withAnimation {
                showDatePicker = true
            }
        } label: {
            Label("Jump to Date", systemImage: "calendar.badge.clock")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.orange, Color(uiColor: UIColor.tertiarySystemFill))
        }
    }

    // MARK: - Date Picker Sheet

    private func datePickerSheet(_ containingGeometry: GeometryProxy) -> some View {
        AnimatingSheetContent(isPresented: $showDatePicker, containingGeometry: containingGeometry, globalFrameName: id) { _ in
            VStack {
                HStack {
                    Menu {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach([AlgoliaSearchParam.Tag.ask_hn, AlgoliaSearchParam.Tag.show_hn, AlgoliaSearchParam.Tag.story].filter(
                                \.self, !=, selectedCategory
                            )) { option in
                                Label(option.label, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                    } label: {
                        Label(selectedCategory.label, systemImage: selectedCategory.systemImage)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.orange, Color(uiColor: UIColor.tertiarySystemFill))
                    }
                    .font(.title3)
                    Spacer()
                    let yesterday = getDateOffset(1)!
                    let (_, day, month, _) = formatDate(yesterday)
                    Button {
                        updateDayForDate(yesterday)
                    } label: {
                        Text("Jump to \(month) \(day)")
                        Text("")
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .disabled(yesterday == selectedDay.date)

                }
                // TODO: Why height too small console log?
                // TODO: date changes whenever month or year changes as it selects a date
                DatePicker("Jump to Date", selection: dateBinding, in: ...getDateOffset(1)!, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
            .padding()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

//    var rollTransition: AnyTransition {
//        AnyTransition.asymmetric(
//            insertion: .offset(x: 0, y: 30),
//            removal: .offset(x: 0, y: -30)
//        )
//    }

    private var numericFilters: [AlgoliaSearchParam.NumericFilter] {
        [.createdAt(.greaterThan(), selectedDay.time)]
    }

    fileprivate static func createDays(_ date: Date = Date()) -> [PastDay] {
        var days: [PastDay] = []
        // -3, -2, -1, 0, 1, 2, 3
        for i in -3...3 {
            days.append(
                PastDay(offset: i, date: getDateOffset(date: date, i)!)
            )
        }
        return days
    }

    private func handleDayChange(_ newSelectedDay: PastDay) async {
        /**
         if final index (future most day) make up to 7 more days in the future
         if first index (past most day) make 7 more days in the past
         create days does a weird thing where it creates 3 days before and 3 days after the provided date
         //so we ask for a date that is 3 before/after ours so we are the first/last created option
         and we need 1 item in the options list on either side of the 7 days

         */
        if let index = options.firstIndex(of: newSelectedDay) {
            if index == options.finalIndex {
//                options.append(PastDay(offset: newSelectedDay.offset + 1, date: getDateOffset(date: newSelectedDay.date, 1)!))
                let prev7Days = PastStoriesScreen.createDays(getDateOffset(date: newSelectedDay.date, 3)!)
                var newOptions = [PastDay(offset: -1, date: getDateOffset(date: newSelectedDay.date, -1)!), selectedDay]
                newOptions.append(contentsOf: prev7Days[1...])
                options = newOptions
            } else if index == options.startIndex && newSelectedDay.date < getDateOffset(1)! {
//                options.insert(PastDay(offset: -1, date: getDateOffset(date: newSelectedDay.date, -1)!), at: 0)
                let next7Days = PastStoriesScreen.createDays(getDateOffset(date: newSelectedDay.date, -3)!)
                var newOptions = next7Days[..<next7Days.finalIndex]
                newOptions.append(contentsOf: [selectedDay, PastDay(offset: 1, date: getDateOffset(date: newSelectedDay.date, 1)!)])
                options = Array(newOptions)
            }
        }
        if dayCategoryResults[newSelectedDay]?[selectedCategory] == nil {
            await searchVm.search(.init(
                searchType: .best, tags: [.story, selectedCategory],
                numericFilter: [
                    .createdAt(.greaterThan(), newSelectedDay.time),
                    .createdAt(.lessThan(), unixTime(date: newSelectedDay.date, -1)!)
                ]
            )
            )
        }
        withAnimation {
            showDatePicker = false
        }
    }

    private func updateDayForDate(_ date: Date) {
        let createdDays = PastStoriesScreen.createDays(date)
        var pastDays = createdDays.filter { $0.date < getDateOffset(0)! }
        let pastDaysToAdd = createdDays.count - pastDays.count

        if pastDaysToAdd > 0 {
            for i in (1...pastDaysToAdd).reversed() {
                pastDays.append(PastDay(offset: 7 - i, date: getDateOffset(7 - i)!))
            }
            pastDays.append(PastDay(offset: 4, date: getDateOffset(date: date, 4)!))
            options = pastDays
            selectedDay = options[3 - pastDaysToAdd]
        } else {
            var newOptions = [PastDay(offset: -4, date: getDateOffset(date: date, -4)!)]
            newOptions.append(contentsOf: pastDays)
            newOptions.append(PastDay(offset: 4, date: getDateOffset(date: date, 4)!))
            options = newOptions
            selectedDay = options[4]
        }
    }

    private func updateCategoryResults(_ results: [SearchResult]?) {
        var dayResults = dayCategoryResults[selectedDay] ?? [:]
        dayResults[selectedCategory] = results?.compactMap { result in
            switch result {
            case .story(let story): return story
            case .comment: return nil
            }
        }
        dayCategoryResults[selectedDay] = dayResults
    }
}

private struct DaySelector: View {
    let option: PastDay
    @Binding var selectedDay: PastDay
    var dateCircleNamespace: Namespace.ID
//    let geometry: GeometryProxy
    //    let draggedXOffset: CGFloat

//    @State private var cursorOffset: CGFloat = .zero

//    let height = 35.0

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(option.weekday[option.weekday.startIndex ..< option.weekday.index(option.weekday.startIndex, offsetBy: 3)])
                .font(.subheadline.smallCaps())
                .fontWeight(.medium)
                .foregroundColor(Color(uiColor: UIColor.lightGray).opacity(0.6))
                .frame(maxWidth: .infinity)
            Button {
                withAnimation {
                    selectedDay = option
                }
            } label: {
                ZStack {
                    if selectedDay.id == option.id {
                        Text(option.dayOfMonth)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(5)
                    } else {
                        Text(option.dayOfMonth)
                            .font(.callout)
                            .padding(5)
                    }
                }
                .frame(maxWidth: .infinity)
                .background {
                    Group {
                        if selectedDay.id == option.id {
                            Circle()
                                .foregroundColor(.orange.opacity(0.2))
                                .matchedGeometryEffect(id: "circle", in: dateCircleNamespace)
                        } else {
                            Circle()
                                .opacity(0)
                        }
                    }
                }
            }
//            .onChange(of: draggedXOffset) { [draggedXOffset] newValue in
//                if selectedDay.id == option.id {
//                    if ((abs(draggedXOffset) - 20)...(abs(draggedXOffset) + 20)).contains(abs(newValue)) {
//                        if abs(newValue) < geometry.size.width / 3.5 {
//                            withAnimation {
//                                cursorOffset = newValue / 10
//                            }
//                        } else {
//                            withAnimation(.easeOut(duration: 0.2)) {
//                                cursorOffset = newValue > 0 ? 54 : -54
//                            }
//                        }
//                    } else {
//                        withAnimation {
//                            cursorOffset = .zero
//                        }
//                    }
//                }
//            }
        }
    }
}

// MARK: - What to do with you?

func getDateOffset(date: Date = Date(), _ dayOffset: Int) -> Date? {
    let c = Calendar.current
    var dateComponent = DateComponents()
    // TODO: make non-negative
    dateComponent.day = -dayOffset
    return c.date(byAdding: dateComponent, to: c.startOfDay(for: date))
}

func unixTime(date: Date = Date(), _ dayOffset: Int) -> Int? {
    let d = getDateOffset(date: date, dayOffset)
    if let d {
        return Int(d.timeIntervalSince1970)
    }
    return .none
}

private struct PastDay: Hashable, CustomStringConvertible, Codable, Identifiable {
    let offset: Int
    var date: Date
    var time: Int { Int(date.timeIntervalSince1970) }
    var label: String {
        let (_, day, month, year) = formatDate(date)
        return "\(month) \(day), \(year)"
    }

    var dayOfMonth: String {
        let (_, day, _, _) = formatDate(date)
        return "\(day)"
    }

    var weekday: String {
        let (dow, _, _, _) = formatDate(date)
        return dow
    }

    var id: Int {
        Int(date.timeIntervalSince1970)
    }

    var description: String { label }
}

// struct PListPage_Previews: PreviewProvider {
//    static var previews: some View {
//        PastStoriesPage()
//    }
// }
