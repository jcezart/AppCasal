//
//  ProgressBar.swift
//  AppCasal
//

import SwiftUI

/// Thin terracotta progress bar used by goals.
struct ProgressBar: View {
    /// 0...1
    let value: Double

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceMuted)
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(Text("Progresso"))
        .accessibilityValue(Text(clamped, format: .percent.precision(.fractionLength(0))))
    }

    private var clamped: Double { min(max(value, 0), 1) }
}

#Preview {
    VStack(spacing: Spacing.m) {
        ProgressBar(value: 0)
        ProgressBar(value: 0.6)
        ProgressBar(value: 1)
    }
    .padding()
    .background(Palette.canvas)
}
