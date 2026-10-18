//
//  MomentsDestination.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// The screen of a `MomentsRoute`. A route whose data is missing on this device (deleted,
/// from another space or not synced yet) shows that instead of another record.
struct MomentsDestination: View {
    let context: MomentsContext
    let route: MomentsRoute

    var body: some View {
        switch route {
        case .explore: ExploreMomentsView(context: context)
        case .daily(let dayKey): DailyQuestionView(context: context, dayKey: dayKey)
        case .history: DailyHistoryView(context: context)
        case .dates: DatesView(context: context)
        case .ideas: DateIdeasView(context: context)
        case .plans: DatePlansView(context: context)
        case .gesture: GestureView(context: context)
        case .revive: ReviveView(context: context)
        case .game: GameView(context: context)
        case .memory(let id): memory(id)
        }
    }

    @ViewBuilder
    private func memory(_ id: UUID) -> some View {
        // Only memories of this space, not deleted.
        if let memory = context.space.memories?.first(where: { $0.id == id && $0.deletedAt == nil }) {
            MemoryDetailView(environment: context.environment, memory: memory, userRecordName: context.userRecordName)
        } else {
            EmptyStateView(
                systemImage: "photo.on.rectangle.angled",
                title: "Memória indisponível",
                message: "Ela foi excluída ou ainda não chegou a este iPhone pelo iCloud."
            )
            .frame(maxHeight: .infinity)
            .canvasBackground()
        }
    }
}
