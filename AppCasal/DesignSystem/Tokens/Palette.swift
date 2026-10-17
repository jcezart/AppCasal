//
//  Palette.swift
//  AppCasal
//

import SwiftUI

/// Semantic colors from the reference image. Values (light and dark) live in
/// `Assets.xcassets`; views use these names, never raw hex values.
enum Palette {
    /// Screen background (warm cream).
    static let canvas = Color(.canvas)
    /// Cards and stable reading surfaces.
    static let surface = Color(.surface)
    /// Chips, banners and inactive controls.
    static let surfaceMuted = Color(.surfaceMuted)
    /// Filled buttons, selection, progress.
    static let accent = Color(.terracotta)
    /// Text and icons on `accent` fills.
    static let onAccent = Color(.onTerracotta)
    /// Small terracotta text and icons on light surfaces (meets 4.5:1).
    static let accentText = Color(.terracottaText)
    static let textPrimary = Color(.ink)
    static let textSecondary = Color(.inkSecondary)
    static let success = Color(.leaf)
    static let hairline = Color(.hairline)
}
