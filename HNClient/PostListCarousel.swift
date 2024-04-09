//
//  PostListCarousel.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-13.
//

import SwiftUI

struct PostListCarousel<Content: View, Dragger: View, Utilities: View, P: RandomAccessCollection>: View where P.Element: Equatable, P.Element: Hashable {
    var fetchStatus: AlgoliaAPI.FetchStatus
    var options: P
    @Binding var pageType: P.Element
    @Binding var listHeaderOffset: CGFloat
    @ViewBuilder var content: (GeometryProxy) -> Content
    @ViewBuilder var utilities: () -> Utilities
    @ViewBuilder var draggableItem: () -> Dragger
    var wrapAround = true
    let containingGeometry: GeometryProxy
    
    init(_ options: P, fetchStatus: AlgoliaAPI.FetchStatus, pageType: Binding<P.Element>, titleYOffset: Binding<CGFloat>, pageSwipeDirection: Binding<Edge>, wrap: Bool = true, containingGeometry: GeometryProxy, draggedXOffset: Binding<CGFloat>, content: @escaping (GeometryProxy) -> Content, utilities: @escaping () -> Utilities, draggableItem: @escaping () -> Dragger) {
        self.fetchStatus = fetchStatus
        self.options = options
        self.wrapAround = wrap
        self._pageType = pageType
        self._listHeaderOffset = titleYOffset
        self.content = content
        self.utilities = utilities
        self.draggableItem = draggableItem
        self._pageSwipeDirection = pageSwipeDirection
        self.containingGeometry = containingGeometry
        self._draggedXOffset = draggedXOffset
    }
    
    // MARK: State
    
    @Binding var draggedXOffset: CGFloat
    @Binding var pageSwipeDirection: Edge
    
    private var pageTitle: String { String(describing: pageType) }
    private var currentIndex: P.Index { options.firstIndex(of: pageType) ?? options.startIndex }
    
    // TODO: what to do if not in collection or what to do if only one item passed in to options?
    private var previousPage: P.Element {
        options[currentIndex == options.startIndex ? options.index(options.endIndex, offsetBy: -1) : options.index(currentIndex, offsetBy: -1)]
    }

    private var nextPage: P.Element {
        options[currentIndex == options.finalIndex ? options.startIndex : options.index(after: currentIndex)]
    }

    private var canWrapForward: Bool { wrapAround || currentIndex != options.finalIndex }
    private var canWrapBackward: Bool { wrapAround || currentIndex != options.startIndex }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ZStack(alignment: .top) {
                    Rectangle().fill(Color(uiColor: UIColor.systemBackground))
                    switch fetchStatus {
                    case .idle, .fetching:
                        content(geometry)
//                            .loading(status: fetchStatus)
                    case .failed(reason: let reason): SomethingWentWrong(errorReason: reason)
                    }
                }
//                pageTypeMenu(geometry: containingGeometry)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    //                pageAction(.trailing)
    //                    .opacity(canWrapBackward ? 1 : 0)
    //                Spacer()
    //                pageAction(.leading)
    //                    .opacity(canWrapForward ? 1 : 0)
    
    // MARK: - ToolBar
    
    func toolbar(_ navBarGeometry: GeometryProxy) -> some View {
        ZStack {
            HStack {
                Text(pageTitle)
                    .animation(.none)
                    .fontWeight(.medium)
                    .offset(y: max(navBarGeometry.size.height - listHeaderOffset, 0))
                    .opacity(1.0 - (max(navBarGeometry.size.height + 20 - listHeaderOffset, 0) / 100.0))
            }
            .frame(maxHeight: .infinity)
            .clipped()
            HStack {
                pageAction(.trailing)
                    .opacity(canWrapBackward ? 1 : 0)
                Spacer()
                pageAction(.leading)
                    .opacity(canWrapForward ? 1 : 0)
            }
        }
    }
    
    // MARK: - Page Type Menu

    @ViewBuilder
    private func pageTypeMenu(geometry: GeometryProxy) -> some View {
        let swiperSegmentWidth = geometry.size.width
        let utilityBarHeight: Double = 30
        GeometryReader { _ in
            ZStack(alignment: .trailing) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .opacity(draggedXOffset <= 0 && canWrapBackward ? 1 : 0)
                        .foregroundColor(.secondary)
                    draggableItem()
                    Image(systemName: "chevron.right")
                        .opacity(draggedXOffset >= 0 && canWrapForward ? 1 : 0)
                        .foregroundColor(.secondary)
                }
                .offset(y: -5)
                .frame(width: swiperSegmentWidth)
                .directionalDrag(draggedOffset: $draggedXOffset, end: swiperSegmentWidth / 2.0, endBuffer: swiperSegmentWidth / 4.0, swipingDirection: $pageSwipeDirection) { swipeDirection in
                    withAnimation {
                        if swipeDirection == .leading && canWrapForward {
                            pageType = nextPage
                        } else if swipeDirection == .trailing && canWrapBackward {
                            pageType = previousPage
                        }
                        if !canWrapForward {
                            withHapticFeedback(.error) {}
                        }
                    }
                }
            }
            .frame(height: utilityBarHeight)
        }
        .background(content: {
            Rectangle()
                .fill(Material.ultraThin)
                .edgesIgnoringSafeArea(.bottom)
        })
        .frame(height: max(0, geometry.safeAreaInsets.bottom + utilityBarHeight))
    }
    
    // MARK: - Page Action
    
    @ViewBuilder
    private func pageAction(_ targetSwipeDirection: Edge) -> some View {
        var historyStack: [P.Element] {
            if targetSwipeDirection == .leading && !wrapAround {
                return Array(options[options.index(after: currentIndex)...])
            } else {
                return []
            }
        }
        var targetPage: P.Element { targetSwipeDirection == .trailing ? previousPage : nextPage }

        Arrows(draggedXOffset: draggedXOffset, targetSwipeDirection: targetSwipeDirection, currentSwipeDirection: pageSwipeDirection, pageTitle: String(describing: targetPage))
            .foregroundColor(.accentColor)
            .onTapGesture {
                withAnimation {
                    pageType = targetPage
                }
            }
            .contextMenu {
                ForEach(historyStack, id: \.self) { element in
                    Button(String("\(element)"), action: {
                        // TODO: page indicator takes a moment to blank off
                        withAnimation {
                            pageType = element
                        }
                    })
                }
            }
    }
}
