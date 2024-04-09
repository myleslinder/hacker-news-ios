//
//  UtilityViews.swift
//  HNClient
//
//  Created by Myles Linder on 2023-07-26.
//

import SafariServices
import SwiftUI


struct BubblingNavLink<V: Hashable, C: View>: View {
    private let sheetNavigation: SheetNavigation = .shared

    let value: V
    var label: () -> C
    var matched: Bool {
        SheetNavigation.supportedTypes.contains(where: { $0 is V.Type })
    }

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationLink(value: value) {
                EmptyView()
            }
            .opacity(0)
            if !matched && sheetNavigation.sheetRootValue != nil {
                label()
                    .onTapGesture { // Override navlink gesture - send to root stack
                        sheetNavigation.moveToTab(value: value)
                    }
            } else {
                label()
            }
        }
    }
}

extension View {
    func hideNavbarTitle() -> some View {
        self.toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
            }
        }
    }
}


struct CommentListItem: View {
    let title: String
    let author: String
    let createdAt: Int
    let htmlText: AttributedString?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            if let htmlText {
                Text(htmlText)
                    .lineLimit(2)
            }
            HStack {
                Label(author, systemImage: "person")
                Text("·")
                Text(formattedDateString(createdAt))
                    .fontWeight(.light)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 5)
    }
}

extension Text {
    func screenTitle() -> some View {
        self
            .font(.title2)
            .fontWeight(.black)
    }
}


struct LoadingFrame: View {
    let geometry: GeometryProxy

    @State private var appeared = false

    @State private var randomFactorMiddle = 0.0
    @State private var randomFactorBottom = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 5)
                .shimmer()
                .frame(width: geometry.size.width / 6, height: 20)
            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 5)
                        .shimmer(offset: randomFactorMiddle)
                        .frame(width: (geometry.size.width / 1.25) + randomFactorMiddle, height: 20)
                    RoundedRectangle(cornerRadius: 5)
                        .shimmer(offset: randomFactorBottom)
                        .frame(width: geometry.size.width / 4 + randomFactorBottom, height: 20)
                }
            }
        }
        .foregroundColor(Color.tertiarySystemFill)
        .padding(.vertical, 5).onAppear { appeared = true }
        .onAppear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                let factor = geometry.size.width / 8
                randomFactorMiddle = Double.random(in: -factor ... factor)
                randomFactorBottom = Double.random(in: 0 ... factor)
            }
        }
    }
}


struct AnimatingSheetContent<Content: View, T: Hashable>: View {
    @Binding var isPresented: Bool
    let containingGeometry: GeometryProxy
    let globalFrameName: T
    let content: (GeometryProxy) -> Content

    // MARK: neat trick
    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(globalFrameName))
            let globalFrame = containingGeometry.frame(in: .global)
            if frame.minX >= 0 { // Bugfix for left to right shift when pops up over keyboard, FIX ROOT layout constraint ISSUE
                content(proxy)
                    .onChange(of: frame.origin.y) { newValue in
                        if newValue > globalFrame.maxY + 0 {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }
                    .background(Color.secondarySystemBackground)
            }
        }
        .frame(minWidth: containingGeometry.size.width)
        .background(Color.secondarySystemBackground)
    }
}


// MARK: - FIX ME

class SFD {
    static let shared = SF()
}

class SF: NSObject, SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController){
        print("VDSVSVSVSVS")
//        let tabSelection = TabSelection.shared
//        tabSelection.tabs[tabSelection.currentTabIndex].path.removeLast()
    }

}

struct SFSafariViewWrapper: UIViewControllerRepresentable {
    let url: URL
    

    func makeUIViewController(context: UIViewControllerRepresentableContext<Self>) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = .systemBackground
        controller.dismissButtonStyle = .close
        controller.delegate = SFD.shared
//        let delegate: SFSafariViewControllerDelegate
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SFSafariViewWrapper>) {}
}

// MARK: - Navigation

struct SheetNavigationLink<Content: View, Data: Hashable>: View {
    private let sheetNavigation: SheetNavigation = .shared

    let value: Data
    @ViewBuilder var content: () -> Content

    var body: some View {
        if sheetNavigation.sheetRootValue != nil {
            NavigationLink(value: value) {
                content()
            }
        } else {
            Button {
                sheetNavigation.destination(value: value)
            } label: {
                content()
            }
        }
    }
}


struct OptionalId<Id: Hashable>: ViewModifier {
    let id: Id?
    func body(content: Content) -> some View {
        if let id {
            content.id(id)
        } else {}
    }
}

extension View {
    func optionalId<Id: Hashable>(_ id: Id) -> some View {
        modifier(OptionalId(id: id))
    }
}

struct EmptyStateModifier: ViewModifier {
    let isEmpty: Bool
    let text: String
    var subtext: String? = .none

    func body(content: Content) -> some View {
        if isEmpty {
            EmptyState(text: text, subtext: subtext)
        } else {
            content
        }
    }
}

struct LoadingIndicator: ViewModifier {
    var isFetching: Bool

    var spinner: some View {
        ZStack(alignment: .center) {
            Circle()
                .frame(width: 30, height: 30)
                .foregroundColor(.black)
                .background {
                    Color.black.opacity(0.3)
//                        .colorMultiply(color)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                }
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.headline)
                .foregroundColor(.white)
//                .rotationEffect(Angle(degrees: y * 6), anchor: .center)
//                .animation(.linear, value: y > 34)
        }
    }
    
    func body(content: Content) -> some View {
        ZStack {
                content
            Group {
                if isFetching {
                    VStack {
                        Spacer()
                        LoadingSpinner()
//                            .padding(.top)
//                            .offset(y: -200)
                        Spacer()
                    }
                    .padding(.top)
                    
                    .frame(maxWidth: .infinity)
                    .transition(
                        .asymmetric(insertion: .opacity.animation(.linear), removal: .opacity.animation(.linear(duration: 0.5)))
                    )
                }
            }
        }
    }
}

extension View {
    func loading(_ isFetching: Bool) -> some View {
        modifier(LoadingIndicator(isFetching: isFetching))
    }

    func empty(_ isEmpty: Bool, _ text: String, subtext: String? = .none) -> some View {
        modifier(EmptyStateModifier(isEmpty: isEmpty, text: text, subtext: .none))
    }

    func directionalDrag(draggedOffset: Binding<CGFloat>, end: Double, endBuffer: Double, direction: DirectionalDrag.Direction = .horizontal, swipingDirection: Binding<Edge>, onSwipeEnd: @escaping (Edge) -> Void) -> some View {
        modifier(DirectionalDrag(draggedOffset: draggedOffset, end: end, endBuffer: endBuffer, direction: direction, swipingDirection: swipingDirection, onSwipeEnd: onSwipeEnd))
    }
}

struct DirectionalDrag: ViewModifier {
    @Binding var draggedOffset: CGFloat

    var end: Double
    var endBuffer: Double

    var direction: Direction = .horizontal
    // only supports leading and trailing
    @Binding var swipingDirection: Edge

    var onSwipeEnd: (Edge) -> Void

    private var offset: CGSize {
        if direction == .horizontal {
            return CGSize(width: draggedOffset, height: 0)
        }
        return CGSize(width: 0, height: draggedOffset)
    }

    private var positiveDirection: Edge { direction == .horizontal ? .leading : .top }
    private var negativeDirection: Edge { direction == .horizontal ? .trailing : .bottom }

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .gesture(dragger)
    }

    private var dragger: some Gesture {
        DragGesture()
            .onChanged { value in
                let keypath = direction == .horizontal ? \CGSize.width : \CGSize.height
                draggedOffset = value.translation[keyPath: keypath]
                if draggedOffset > 0, swipingDirection != .leading {
                    swipingDirection = positiveDirection
                } else if draggedOffset < 0, swipingDirection != .trailing {
                    swipingDirection = negativeDirection
                }
            }
            .onEnded { value in
                let keyPath = direction == .horizontal ? \CGSize.width : \CGSize.height
                let endX = value.predictedEndTranslation[keyPath: keyPath]
                let x = value.translation[keyPath: keyPath]
                withAnimation(.spring(dampingFraction: 0.4, blendDuration: 0.5)) {
                    draggedOffset = .zero
                }
                withAnimation {
                    if endX < -end || x < -(end - endBuffer) {
                        onSwipeEnd(negativeDirection)
                    } else if endX > end || x > end - endBuffer {
                        onSwipeEnd(positiveDirection)
                    }
                }
            }
    }

    enum Direction {
        case horizontal
        case vertical
    }
}

struct Arrows: View {
    let count = [1]
    let draggedXOffset: CGFloat
    let targetSwipeDirection: Edge
    let currentSwipeDirection: Edge
    let pageTitle: String

    private func compare<T: Comparable>(_ a: T, _ b: T) -> Bool { targetSwipeDirection == .leading ? (>)(a, b) : (<)(a, b) }

    private func opacity(_ idx: Int) -> Double {
        compare(draggedXOffset, 0) ? max(0.30, abs(draggedXOffset / 100) / (Double(idx) / 3)) : 0
    }

    private var items: [Int] {
        targetSwipeDirection == .trailing ? count.reversed() : count
    }

    private var imageSystemName: String {
        targetSwipeDirection == .leading ? "chevron.right" : "chevron.left"
    }

    var label: some View {
        let chevron = Image(systemName: imageSystemName)
            .font(.caption2)
        return HStack {
            if targetSwipeDirection == .trailing {
                chevron
            }
            Text(displayTitle.uppercased())
                .fontWeight(.medium)
                .opacity(max(opacity(3), 0.9))
                .font(.caption2)
            if targetSwipeDirection == .leading {
                chevron
            }
        }
        .font(.callout.smallCaps())
    }

    @State private var innerTitle: String = ""
    private var displayTitle: String {
        innerTitle.isEmpty ? pageTitle : innerTitle
    }

    @State private var showArrows = false
    var body: some View {
        HStack(spacing: 2) {
            if targetSwipeDirection == .leading {
                label
            }
            if targetSwipeDirection == currentSwipeDirection, draggedXOffset != 0 {
                HStack(spacing: 2) {
                    ForEach(items, id: \.self) { idx in
                        Image(systemName: imageSystemName)
                            .font(.caption2)
                            .scaleEffect(1 + (Double(items.count - idx + 1) / 20))
                            .opacity(opacity(items.count - idx + 1))
//                                .transition(.asymmetric(
//                                    insertion: .push(from: targetSwipeDirection).animation(.default.delay(Double(idx) / 10)),
//                                    removal: .identity.animation(.easeInOut))
//                                )
                    }
                }
            }

            if targetSwipeDirection == .trailing {
                label
            }
        }
        .onChange(of: pageTitle, perform: { newTitle in
            innerTitle = newTitle
        })
    }
}

struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct NavBar<T: View, B: View>: View {
    var yOffset: CGFloat
    @ViewBuilder var title: () -> T
    @ViewBuilder var toolbar: () -> B
    var body: some View {
        GeometryReader { navBarGeometry in
            ZStack {
                title()
                    .offset(y: max(navBarGeometry.size.height + 5 - yOffset, 0))
                    .opacity(1.0 - (max(navBarGeometry.size.height + 30 - yOffset, 0) / 100.0))
                HStack {
                    toolbar()
                }
                .padding(.horizontal)
            }
        }
    }
}


// MARK: - Loading Indicator

struct LoadingSpinner: View {
    var body: some View {
        ZStack(alignment: .center) {
            ProgressView()
                .scaleEffect(2)
        }
    }
}

// MARK: - Overlay Button

struct OverlayButton: View {
    private let imageSystemName: String
    private let dimension: CGFloat
    private let offset: CGSize

    var body: some View {
        Image(systemName: imageSystemName)
            .foregroundColor(.white)
        .font(.system(size: dimension / 2.5))
        .fontWeight(.semibold)
        .frame(width: dimension, height: dimension)
        .background { Circle().foregroundColor(.secondary) }
        .offset(x: offset.width, y: offset.height)
        .contentShape(ContentShapeKinds.contextMenuPreview, Circle())
    }

    init(_ imageSystemName: String, dimension: CGFloat = 50, offset: CGSize = CGSize(width: -20, height: -20)) {
        self.imageSystemName = imageSystemName
        self.dimension = dimension
        self.offset = offset
    }
}

// MARK: - Save Button

struct SaveButton: View {
    @JSONAppStorage(\.savedPosts) private var savedPosts
    let post: PostPreview

    private let toggleAnimation = AnyTransition.scale.animation(.spring())

    init(post: PostPreview) {
        self.post = post
        print("SAVE INIT")
    }
    
    private var collection: Binding<[PostPreview]> {
        switch post.type {
        case .comment: return $savedPosts.comments
        case .story: return $savedPosts.stories
        }
    }

    var body: some View {
        StatefulButton(collection: collection, element: post, insertionPosition: .prepend) { contains in
            if contains {
                Label("Remove", systemImage: "bookmark")
                    .symbolVariant(.circle)
                    .symbolVariant(.fill)
//                    .symbolVariant(.)
                    .transition(toggleAnimation)
            } else {
                // MARK: neat trick
                Label("Save", systemImage: "bookmark.circle.fill")
//                    .background(Material.ultraThin)
//                    .mask {
//                        Image(systemName: "bookmark.fill")
//                    }
                    .transition(toggleAnimation)
            }
        }
        .onDisappear {
            print("SAVE BUTTON DISAPPEAR")
        }
//        .statefulTint(present: .red, absent: .orange)
    }
}

struct StatefulButton<E: Identifiable, C: View>: View {
    @Binding var collection: [E]
    let element: E
    var action: ((Bool) -> Void) = { _ in }
    var insertionPosition: Array<E>.ToggleInsertionPosition = .append
    @ViewBuilder let label: (Bool) -> C

    private var collectionContainsElement: Bool {
        collection.contains(where: { $0.id == element.id })
    }

    var body: some View {
        Button {
            print("TAPPING ME")
            withHapticFeedback(.success) {
                collection.toggle(element, insertionPosition)
                action(collectionContainsElement)
            }
        } label: {
            label(collectionContainsElement)
        }
    }
}

struct StatefulTint: ViewModifier {
    let isInCollection: Bool
    let present: Color
    let absent: Color
    func body(content: Content) -> some View {
        content
            .tint(isInCollection ? present : absent)
    }
}

extension StatefulButton {
    func statefulTint(present: Color, absent: Color) -> some View {
        modifier(StatefulTint(isInCollection: collectionContainsElement, present: present, absent: absent))
    }
}

// MARK: - Tabbed List

struct TabbedList<Content, Header, Data, T>: View
    where Content: View,
      Header: View,
    Data: MutableCollection & RandomAccessCollection,
    Data.Element: Identifiable,
    Data.Index: Hashable,
    T: CaseIterable & Hashable & RawRepresentable & SystemImageConvertible,
    T.AllCases: RandomAccessCollection,
    T.RawValue == String
{
    @Binding var selection: T
    var data: (T) -> Binding<Data>
    var editActions: EditActions<Data> = []
    var emptyText: String? = .none
    @ViewBuilder let content: (Binding<Data.Element>) -> Content
    @ViewBuilder var header: () -> Header

    var body: some View {
        TabView(selection: $selection) {
            ForEach(T.allCases, id: \.self) { selectedCase in
                let items = data(selectedCase)
                List {
                    header()
                    ForEach(items, editActions: editActions) {    item in
                        content(item)
                    }
                    .id(items.count)
                }
                .empty(items.isEmpty, emptyText ?? "Nothing to see here.")
            }
        }
    }
}

struct TabBar<T, C>: View where T: CaseIterable & Hashable & RawRepresentable & SystemImageConvertible,
    T.AllCases: RandomAccessCollection,
    T.RawValue == String,
    C: View
{
    @Binding var selection: T
    @Namespace private var tabNameSpace
    @ViewBuilder var tabLabel: (T) -> C

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(T.allCases, id: \.self) { type in
                    Button {
                        withAnimation {
                            selection = type
                        }
                    } label: {
                        VStack(spacing: 0) {
                            tabLabel(type)
                                .padding(10)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.orange)
                            ZStack {
                                Rectangle()
                                    .fill(.clear)
                                if selection == type {
                                    Rectangle()
                                        .foregroundColor(.accentColor)
                                        .matchedGeometryEffect(id: "id", in: tabNameSpace)
                                }
                            }
                            .frame(height: 1)
                        }
                    }
                }
            }
            .animation(.easeInOut, value: selection)
            Divider()
        }
    }
}

struct TabbedListTabBar<T>: ViewModifier
    where T: CaseIterable & Hashable & RawRepresentable & SystemImageConvertible,
    T.AllCases: RandomAccessCollection,
    T.RawValue == String
{
    @Binding var selection: T
    var location: Location = .top

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if location == .bottom {
                content
            }
            TabBar(selection: $selection) { type in
                Image(systemName: type.systemImage)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.primary, Color.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top)
            if location == .top {
                content
            }
        }
    }

    enum Location {
        case top
        case bottom
    }
}

extension TabbedList {
    func tabbed(location: TabbedListTabBar<T>.Location = .top) -> some View {
        modifier(TabbedListTabBar(selection: $selection, location: location))
    }
}

// MARK: - Optional Picker

struct OptionalPicker<T, C, E>: View where T: Identifiable & Hashable, C: View, E: View {
    let title: String
    let collection: [T]
    @Binding var selection: T?
    var emptyPosition: EmptyPosition = .last
    @ViewBuilder var label: (T) -> C
    @ViewBuilder var emptyLabel: () -> E

    private var empty: some View { emptyLabel().tag(T?.none) }

    var body: some View {
        Picker(title, selection: $selection) {
            if emptyPosition == .first { empty }
            ForEach(collection) { option in
                label(option).tag(option as T?)
            }
            if emptyPosition == .last { empty }
        }
    }

    init(_ title: String, _ collection: [T], selection: Binding<T?>, emptyPosition: EmptyPosition = .last, label: @escaping (T) -> C, emptyLabel: @escaping () -> E) {
        self.title = title
        self.collection = collection
        self._selection = selection
        self.emptyPosition = emptyPosition
        self.label = label
        self.emptyLabel = emptyLabel
    }

    enum EmptyPosition {
        case first
        case last
    }
}

// MARK: - Empty State

struct Shimmer: ViewModifier {
    var offset: Double = 2

    @State private var appeared: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.quaternarySystemFill)
                        .offset(x: appeared ? proxy.size.width + offset : -(proxy.size.width + offset))
                        .animation(.linear(duration: 2).delay(0.1).repeatForever(autoreverses: false), value: appeared)
                        .blur(radius: 10)
                }
            }
            .clipped()
            .onAppear { appeared = true }
    }
}

extension View {
    func shimmer(offset: Double? = nil) -> some View {
        modifier(Shimmer(offset: offset ?? 0))
    }
}


struct EmptyState: View {
    let text: String
    var subtext: String? = .none
    var body: some View {
        //        Spacer()
        VStack(spacing: 20) {
            Image(systemName: "space")
                .font(.title)
                .foregroundColor(.accentColor)
            Text(text)
                .font(.title)
            if let subtext {
                Text(subtext)
                    .padding()
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .multilineTextAlignment(.center)
        Spacer()
    }
}

struct EmptySearch: View {
    var body: some View {
//        Spacer()
        VStack(spacing: 20) {
            VStack(spacing: 20) {
                Image(systemName: "mail.and.text.magnifyingglass")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.primary, Color.secondary)
                    .font(.largeTitle)
                Text("Search for stories or comments")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.title)
            }
            VStack(spacing: 15) {
                Text("use @ and an author name to search for an author. Multiple authors are OR'd")
                Text("Set one or more search filters which are AND'd")
            }
            .padding()
            .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
//        Spacer()
    }
}

// MARK: - App State Views

struct SomethingWentWrong: View {
    var errorReason: String? = .none

    var body: some View {
        Spacer()
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.square.fill")
                .symbolRenderingMode(.multicolor)
                .font(.largeTitle)
            Text(errorReason ?? "Looks like something went wrong")
                .font(.title3)
            Text("Try refreshing the page or closing the app.")
                .padding()
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding()
        .multilineTextAlignment(.center)
        Spacer()
    }
}

struct NoSearchResults: View {
    var body: some View {
        Spacer()
        VStack(spacing: 20) {
            Image(systemName: "space")
                .font(.title)
                .foregroundColor(.accentColor)
            Text("There are no results for your search.")
                .font(.title)
            Text("Try a different search")
                .padding()
                .foregroundColor(.secondary)
        }
        .padding()
        .multilineTextAlignment(.center)
        Spacer()
    }
}

