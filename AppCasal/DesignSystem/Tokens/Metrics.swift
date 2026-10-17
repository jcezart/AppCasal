//
//  Metrics.swift
//  AppCasal
//

import CoreGraphics

/// 4-point spacing scale.
nonisolated enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40

    /// Horizontal screen margin.
    static let screen: CGFloat = 20
    /// Inner padding of cards.
    static let card: CGFloat = 16
}

/// Corner radii. Always used with continuous corners.
nonisolated enum Radius {
    static let card: CGFloat = 20
    static let photo: CGFloat = 14
    static let button: CGFloat = 14
}
