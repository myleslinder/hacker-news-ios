//
//  TabSelection.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-17.
//

import Combine
import Foundation
import SwiftUI

extension TabSelection.TabId {
    var label: String {
        switch self {
        case .category: return "Stories"
        case .past: return "Past"
        case .search: return "Search"
        case .profile: return "Profile"
        }
    }
    
    var systemImage: String {
        switch self {
        case .category: return "rectangle.stack" // "mail.stack" //"doc.text.image.fill"
        case .past: return "arrowshape.turn.up.left"//"arrow.left.square"
        case .search: return "magnifyingglass"
        case .profile: return "person.crop.circle"
        }
    }
    
    // TODO: FIX the .fill for sure
    func image(isActive: Bool) -> Image {
        switch self {
        case .search:  return Image(uiImage: img( isActive ? "\(self.systemImage)" : self.systemImage, rotate: false, config: isActive ? .init(weight: .bold) : .none))
        default:
            return Image(uiImage: img(isActive ? "\(self.systemImage).fill" : self.systemImage))
        }
    }
    
    private func img(_ systemName: String, rotate: Bool = false, config: UIImage.SymbolConfiguration? = .none) -> UIImage {
        var image = UIImage(systemName: systemName)!
        image = image.applyingSymbolConfiguration(.init(scale: .large))!
        if let config {
            image = image.applyingSymbolConfiguration(config)!
        }
        if rotate {
            return UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .right)
        }
        return image
        
    }
}


// NOTE: any has a performance cost
typealias MoveToTabAction = (any Hashable) -> Void

private struct NavigateInMainTab: EnvironmentKey {
    static let defaultValue: MoveToTabAction? = .none
}


extension EnvironmentValues {
    var navigateInCurrentTab: MoveToTabAction? {
        get { self[NavigateInMainTab.self] }
        set { self[NavigateInMainTab.self] = newValue }
    }
}

extension View {
    func allowMainTabNavigation() -> some View {
        environment(\.navigateInCurrentTab, { value in
            SheetNavigation.shared.moveToTab(value: value)
        })
    }
}


class SheetNavigation: ObservableObject {
    static let shared = SheetNavigation()

    @Published var sheetRootValue: SheetRootItem<AnyHashable>? = .none
    func destination<D>(value: D) where D: Hashable {
        sheetRootValue = SheetRootItem(value: value)
    }
    private(set) var tabs: [TabSelection.TabId : Tab] = [:]
    func registerTab(_ tab: Tab) {
        tabs[tab.id] = tab
    }

    func moveToTab<D: Hashable>(value: D) {
        tabs[TabSelection.shared.selections.current]?.path.append(value)
        sheetRootValue = .none
    }

    struct SheetRootItem<D: Hashable>: Identifiable {
        let value: D
        var id: D { value.self }
    }

    static let supportedTypes: [Any] = [NavigableHNUser.self]
}


class Tab: ObservableObject {
    let id: TabSelection.TabId
    @Published var path: NavigationPath
    private var tapAction: (() -> Void)?

    private var tapCancellable: AnyCancellable? = .none

    func assignTapAction(for id: TabSelection.TabId, action: @escaping () -> Void) {
        tapAction = action
    }

    @Published var sheetRootValue: SheetRootItem<AnyHashable>? = .none
    struct SheetRootItem<D: Hashable>: Identifiable {
        let value: D
        var id: D {
            value.self
        }
    }

    func sheetDestination<D>(value: D) where D: Hashable {
        sheetRootValue = SheetRootItem(value: value)
    }

    init(id: TabSelection.TabId, path: NavigationPath = .init(), tapAction: (() -> Void)? = nil) {
        self.id = id
        self.path = path
        self.path = path
        self.tapAction = tapAction
        self.tapCancellable = Tab.mapSelections(id)
            .sink { [weak self] _ in
                if let self, !self.path.isEmpty {
                    self.path = .init()
                } else {
                    self?.tapAction?()
                }
            }
        SheetNavigation.shared.registerTab(self)
    }

    private static func mapSelections(_ id: TabSelection.TabId) -> some Publisher<Bool, Never> {
        TabSelection.shared.$selections
            .map { selections in
                selections.current == id && selections.previous == id
            }
            .filter { $0 }
    }
}

class TabSelection: ObservableObject {
    static let shared = TabSelection(selection: .profile)
    @Published private(set) var selections: TabSelections
    
    init(selection: TabId) {
        self.selections = TabSelections(current: selection, previous: .none)
    }

    let tabs: [TabId] = TabSelection.TabId.allCases
    var payloads: [TabId: P] = [
        .search: P(String.self),
    ]

    func updateSelections(current: TabId) {
        selections = TabSelections(current: current, previous: selections.current)
    }
    
    struct P<T> {
        private(set) var payload: T?
        init(_ type: T.Type){}
        mutating func setPayload(_ payload: T?) {
            self.payload = payload
        }
    }
    
    enum TabId: CaseIterable, Identifiable, Equatable, Hashable {
        case category
        case past
        case search
        case profile
        
        // Manually defined to control order
        static var allCases: [TabSelection.TabId] = [
            .category,
            .past,
            .search,
            .profile,
        ]
        
        var id: Self { self }
    }

    struct TabSelections: Equatable {
        var current: TabId
        var previous: TabId?
    }
}

// TabId -> Type -> Payload

protocol Z {
    associatedtype Payload: Hashable
    var id: TabSelection.TabId { get }
    var payload: Payload? { get set }
    var payloadType: Payload.Type { get set }
}

struct Pay<D: Hashable> {
    var load: D? = .none
    var t: D.Type
    
    mutating func setLoad(_ load: D?) {
        self.load = load
    }
}

struct PZ<T: Hashable>: Z {
    typealias Payload = T
    var id: TabSelection.TabId
    var payload: T?
    var payloadType: T.Type
    
    init(_ id: TabSelection.TabId, payloadType: T.Type) {
        self.id = id
        self.payloadType = payloadType
    }
}


