//
//  Typography.swift
//  AppCasal
//

import SwiftUI
import UIKit

/// Type roles. Serif (New York) for titles, names and notes; SF Pro for the rest.
/// All roles are text styles, so they follow Dynamic Type.
nonisolated extension Font {
    static let displayTitle = Font.system(.largeTitle, design: .serif)
    static let sectionTitle = Font.system(.title2, design: .serif)
    static let cardTitle = Font.system(.title3, design: .serif)
    static let noteQuote = Font.system(.title3, design: .serif)
    static let metadata = Font.footnote
    static let chipLabel = Font.caption.weight(.medium)
}

enum NavigationAppearance {
    /// Serif navigation titles, matching the reference. UIKit appearance is the only
    /// way to change the font of native navigation titles.
    static func apply() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [
            .font: serifFont(for: .largeTitle),
            .foregroundColor: UIColor(resource: .ink),
        ]
        appearance.titleTextAttributes = [
            .font: serifFont(for: .headline),
            .foregroundColor: UIColor(resource: .ink),
        ]
    }

    private static func serifFont(for style: UIFont.TextStyle) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: 0)
    }
}
