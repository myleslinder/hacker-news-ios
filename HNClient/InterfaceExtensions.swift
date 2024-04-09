//
//  InterfaceExtensions.swift
//  HNClient
//
//  Created by Myles Linder on 2023-09-02.
//

import Foundation
import SwiftUI


// MARK: - Protocols

protocol SystemImageConvertible {
    var systemImage: String { get }
}

// MARK: neat trick
extension View {
    func roundCorners<Content: View>(@ViewBuilder modify: ((GroupBox<EmptyView, Color>) -> Content) = { v in v }) -> some View {
        return self
            .mask {
                modify(GroupBox { Color.clear })
            }
    }
}


extension Color {
    static var systemBackground = Color(uiColor: UIColor.systemBackground)
    static var secondarySystemBackground = Color(uiColor: UIColor.secondarySystemBackground)
    static var tertiarySystemBackground = Color(uiColor: UIColor.tertiarySystemBackground)
    static var lightGray = Color(uiColor: UIColor.lightGray)
    static var darkGray = Color(uiColor: UIColor.darkGray)
    static var secondarySystemFill = Color(uiColor: UIColor.secondarySystemFill)
    static var tertiarySystemFill = Color(uiColor: UIColor.tertiarySystemFill)
    static var quaternarySystemFill = Color(uiColor: UIColor.quaternarySystemFill)
    static var systemGray4 = Color(uiColor: UIColor.systemGray4)
    static var secondaryLabel = Color(uiColor: UIColor.secondaryLabel)
}

protocol ChangeMe: Equatable, Hashable {
    var systemImage: String { get }
    var label: String { get }
}



// MARK: - Drawing Extensions

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

extension CGPoint {
    static func -(lhs: Self, rhs: Self) -> CGSize {
        CGSize(width: lhs.x - rhs.x, height: lhs.y - rhs.y)
    }

    static func +(lhs: Self, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
    }

    static func -(lhs: Self, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x - rhs.width, y: lhs.y - rhs.height)
    }

    static func *(lhs: Self, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func /(lhs: Self, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x/rhs, y: lhs.y/rhs)
    }
}

extension CGSize {
    // the center point of an area that is our size
    var center: CGPoint {
        CGPoint(x: width/2, y: height/2)
    }

    static func +(lhs: Self, rhs: Self) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    static func -(lhs: Self, rhs: Self) -> CGSize {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

    static func *(lhs: Self, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    static func /(lhs: Self, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width/rhs, height: lhs.height/rhs)
    }
}
