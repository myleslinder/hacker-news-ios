//
//  UtilityExtensions.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-23.
//

import Foundation

// MARK: - Array

extension Array where Element: Identifiable {
    /**
      Inserts or replaces the element in the array based on its ID
     - Parameter with: The identifiable element to update or insert
     - Parameter position: A value indicating where to insert the updated element if already present
     - Complexity: O(n), where n is the length of the array.
      */
    mutating func update(with element: Element, position: UpdatePosition = .identity) {
        if let index = firstIndex(where: { $0.id == element.id }) {
            remove(at: index)
            if position == .identity {
                self[index] = element
                return
            } else if position == .prepend {
                insert(element, at: 0)
                return
            }
        }
        append(element)
    }

    enum UpdatePosition {
        case identity
        case append
        case prepend
    }

    /**
      Toggle the element's presence in the array based on its ID
     - Parameter element: The identifiable element to toggle
     - Parameter position: A value indicating where to insert the element if not already present
     - Complexity: If position is prepend then O(n), where n is the length of the array. If position is append, this method is equivalent to append(_:).
      */
    mutating func toggle(_ element: Element, _ position: ToggleInsertionPosition = .append) {
        if let index = firstIndex(where: { $0.id == element.id }) {
            remove(at: index)
        } else {
            insert(element, at: position == .append ? endIndex : 0)
        }
    }

    enum ToggleInsertionPosition {
        case append
        case prepend
    }
}

// MARK: Collections


extension RangeReplaceableCollection where Element: Identifiable {
    mutating func remove(_ element: Element) {
        if let idx = index(matching: element) {
            remove(at: idx)
        }
    }

    subscript(_ element: Element) -> Element {
        get {
            if let idx = index(matching: element) {
                return self[idx]
            } else {
                return element
            }
        }
        set {
            if let idx = index(matching: element) {
                replaceSubrange(idx...idx, with: [newValue])
            }
        }
    }
}

extension RandomAccessCollection {
    var finalIndex: Index { index(endIndex, offsetBy: -1) }
}

extension Collection where Element: Identifiable {
    func index(matching element: Element) -> Self.Index? {
        firstIndex(where: { $0.id == element.id })
    }
}

extension Collection {
    func map<V>(_ keypath: KeyPath<Element, V>) -> [V] {
        map { $0[keyPath: keypath] }
    }

    func sorted<V>(_ keypath: KeyPath<Element, V>, _ op: (V, V) -> Bool) -> [Element] {
        sorted { op($0[keyPath: keypath], $1[keyPath: keypath]) }
    }

    func filter<V>(_ keypath: KeyPath<Element, V>, _ op: (V, V) -> Bool, _ comparison: V) -> [Element] where V: Equatable, Element: Equatable {
        filter { op($0[keyPath: keypath], comparison) }
    }
    func filter<V>(_ op: (V) -> Bool, _ keypath: KeyPath<Element, V>) -> [Element] where V: Equatable, Element: Equatable {
        filter { op($0[keyPath: keypath]) }
    }
    func filter(_ keypath: KeyPath<Element, Bool>) -> [Element] {
        filter { $0[keyPath: keypath] }
    }
}

