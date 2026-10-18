//
//  GoalCard.swift
//  AppCasal
//

import SwiftUI

/// Goal with cover, category, due date, progress and a tappable step checklist.
struct GoalCard: View {
    @ObservedObject var goal: Goal
    let onToggle: (GoalStep) -> Void
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onReopen: () -> Void
    let onDelete: () -> Void

    @ScaledMetric(relativeTo: .body) private var coverSize: CGFloat = 64

    var body: some View {
        GoalStepsObserver(goal: goal) { card }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            header
            if !goal.visibleSteps.isEmpty {
                HStack(spacing: Spacing.s) {
                    ProgressBar(value: goal.progress)
                    Text(goal.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.textSecondary)
                    Text("\(goal.completedStepCount) de \(goal.visibleSteps.count) etapas")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(goal.visibleSteps) { step in
                        StepRow(step: step) { onToggle(step) }
                    }
                }
            }
            if let completedAt = goal.completedAt {
                Label {
                    Text("Concluída em \(completedAt, format: .dateTime.day().month(.wide).year())")
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
                .font(.subheadline)
                .foregroundStyle(Palette.success)
            } else if !goal.visibleSteps.isEmpty, goal.completedStepCount == goal.visibleSteps.count {
                Button("Concluir meta", systemImage: "checkmark.seal", action: onComplete)
                    .buttonStyle(.primary)
            }
        }
        .surfaceCard()
    }

    private var header: some View {
        AdaptiveStack {
            DecodedImage(data: goal.coverPhotoData) {
                Image(systemName: goal.goalCategory.systemImage)
                    .font(.title3)
                    .foregroundStyle(Palette.accentText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.surfaceMuted)
            }
            .frame(width: coverSize, height: coverSize)
            .clipShape(.rect(cornerRadius: Radius.photo, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(goal.title ?? "")
                    .font(.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                FlowChips(goal: goal)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Editar", systemImage: "pencil", action: onEdit)
                if goal.isCompleted {
                    Button("Reabrir", systemImage: "arrow.uturn.backward", action: onReopen)
                } else {
                    Button("Concluir", systemImage: "checkmark.seal", action: onComplete)
                }
                Button("Excluir", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text("Opções da meta"))
        }
    }
}

private struct FlowChips: View {
    @ObservedObject var goal: Goal

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.xs) { chips }
            VStack(alignment: .leading, spacing: Spacing.xs) { chips }
        }
    }

    @ViewBuilder
    private var chips: some View {
        TagChip(title: goal.goalCategory.title, systemImage: goal.goalCategory.systemImage)
        if let dueDate = goal.dueDate {
            if !goal.isCompleted, dueDate < Calendar.current.startOfDay(for: .now) {
                StatusChip(title: "Prazo passou", systemImage: "exclamationmark.circle", tone: .accent)
            } else {
                TagChip(title: Self.dueText(dueDate), systemImage: "clock")
            }
        }
    }

    /// "Até dezembro", or "Até dezembro de 2027" outside the current year.
    static func dueText(_ date: Date) -> String {
        let sameYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        let month = sameYear
            ? date.formatted(.dateTime.month(.wide))
            : date.formatted(.dateTime.month(.wide).year())
        return String(localized: "Até \(month)")
    }
}

private struct StepRow: View {
    @ObservedObject var step: GoalStep
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Image(systemName: step.doneAt == nil ? "square" : "checkmark.square.fill")
                    .foregroundStyle(step.doneAt == nil ? Palette.textSecondary : Palette.accent)
                Text(step.title ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary)
                    .strikethrough(step.doneAt != nil, color: Palette.textSecondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 36)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: step.doneAt)
        .accessibilityLabel(Text(step.title ?? ""))
        .accessibilityValue(step.doneAt == nil ? Text("Pendente") : Text("Feita"))
        .accessibilityAddTraits(.isToggle)
    }
}
