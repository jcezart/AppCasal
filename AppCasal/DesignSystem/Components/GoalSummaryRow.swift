//
//  GoalSummaryRow.swift
//  AppCasal
//

import SwiftUI

/// Compact goal progress used on Início, with the goal's photo ("Nossa próxima viagem · 3 de 5 etapas").
struct GoalSummaryRow: View {
    @ObservedObject var goal: Goal

    var body: some View {
        GoalStepsObserver(goal: goal) { row }
    }

    private var row: some View {
        AdaptiveStack {
            thumbnail
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(goal.title ?? "")
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: Spacing.xs)
                    if !goal.visibleSteps.isEmpty {
                        Text("\(goal.completedStepCount) de \(goal.visibleSteps.count) etapas")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                HStack(spacing: Spacing.s) {
                    ProgressBar(value: goal.progress)
                    Text(goal.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }

    /// The goal's photo; the category icon when there is none.
    private var thumbnail: some View {
        DecodedImage(data: goal.coverPhotoData) {
            Image(systemName: goal.goalCategory.systemImage)
                .foregroundStyle(Palette.accentText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.surfaceMuted)
        }
    }
}
