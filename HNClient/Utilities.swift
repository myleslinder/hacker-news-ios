//
//  Utilities.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-05.
//

import Foundation
import UIKit


extension Collection where Element: Identifiable {
    subscript(_ id: Element.ID) -> Element {
        first(where: { $0.id == id })!
    }
}


func withHapticFeedback(_ notificationType: UINotificationFeedbackGenerator.FeedbackType, _ action: () -> Void) {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    action()
}



// MARK: - Comment Tree Helpers

func buildCommentTree(_ id: Int, comments: [CommentSearchResult]) -> [CommentPost] {
    comments
        .filter { $0.parentId == id }
        .map { CommentPost(from: $0, children: buildCommentTree($0.id, comments: comments)) }
}

func sortComments<T: PostVariant>(post: T, sortablePosts: [HackerNewsAPI.Item]) -> T {
    var p = post
    p.children = post.children.map { child in
        var newChild = child
        if let sortable = sortablePosts.first(where: { $0.id == newChild.id }) {
            newChild.children = sortToMatch(newChild.children, ids: sortable.childIds)
                .map { comment in sortComments(post: comment, sortablePosts: sortablePosts) }
        } else {
            newChild.children = child.children.map { comment in sortComments(post: comment, sortablePosts: sortablePosts) }
        }
        return newChild
    }
    return p
}

func sortToMatch<T: Identifiable>(_ items: [T], ids: [Int]) -> [T] where T.ID == Int {
    items.sorted(by: { a, b in
        if let aIndex = ids.firstIndex(of: a.id),
           let bIndex = ids.firstIndex(of: b.id)
        {
            return aIndex < bIndex
        }
        return false
    })
}

func treeFlatMap<T, V>(_ item: T, value: KeyPath<T, V>, children: KeyPath<T, [T]>) -> [V] {
    var base = [item[keyPath: value]]
    base
        .append(contentsOf:
            item[keyPath: children]
                .map {
                    treeFlatMap($0, value: value, children: children)
                }
                .joined()
        )
    return base
}

// MARK: - Dates

func formatDate(_ date: Date = Date()) -> (dow: String, day: Int, month: String, year: Int) {
    let calendar = Calendar.current
    let day = calendar.component(.day, from: date)
    let weekday = calendar.component(.weekday, from: date)
    let dow = Calendar.current.weekdaySymbols[weekday - 1]
    let monthIndex = calendar.component(.month, from: date)
    let month = calendar.monthSymbols[monthIndex - 1]
    let year = calendar.component(.year, from: date)

    
    
    return (dow: dow, day: day, month: month, year: year)
}

// TODO: understand and fix
func formattedDateString(_ unixTime: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(unixTime))
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full

    let relativeDate = formatter.localizedString(for: date, relativeTo: Date.now)
    return relativeDate
}
