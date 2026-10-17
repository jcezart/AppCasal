//
//  AdaptiveStack.swift
//  AppCasal
//

import SwiftUI

/// Horizontal layout that becomes vertical at accessibility text sizes, so long
/// text never gets squeezed next to icons or photos.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = Spacing.s
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(alignment: .top, spacing: spacing) { content }
        }
    }
}
