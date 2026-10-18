//
//  DeletedItemsView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// "Excluídos recentemente": logically deleted memories, goals, notes, places, reminders,
/// own date ideas and date plans.
/// Either partner restores shared items; notes only by their author. Nothing is purged
/// automatically.
struct DeletedItemsView: View {
    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String

    @FetchRequest private var memories: FetchedResults<Memory>
    @FetchRequest private var goals: FetchedResults<Goal>
    @FetchRequest private var notes: FetchedResults<Note>
    @FetchRequest private var places: FetchedResults<Place>
    @FetchRequest private var reminders: FetchedResults<Reminder>
    @FetchRequest private var ideas: FetchedResults<DateIdea>
    @FetchRequest private var plans: FetchedResults<DatePlan>
    @State private var errorMessage: String?

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        let deleted = NSPredicate(format: "space == %@ AND deletedAt != nil", space)
        _memories = FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Memory.deletedAt, ascending: false)], predicate: deleted)
        _goals = FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Goal.deletedAt, ascending: false)], predicate: deleted)
        _notes = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Note.deletedAt, ascending: false)],
            predicate: NSPredicate(format: "space == %@ AND deletedAt != nil AND authorID == %@", space, userRecordName)
        )
        _places = FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Place.deletedAt, ascending: false)], predicate: deleted)
        _reminders = FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Reminder.deletedAt, ascending: false)], predicate: deleted)
        // Ideas: only their author restores them, like notes.
        _ideas = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \DateIdea.deletedAt, ascending: false)],
            predicate: NSPredicate(format: "space == %@ AND deletedAt != nil AND authorID == %@", space, userRecordName)
        )
        _plans = FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DatePlan.deletedAt, ascending: false)], predicate: deleted)
    }

    private var isEmpty: Bool {
        memories.isEmpty && goals.isEmpty && notes.isEmpty && places.isEmpty && reminders.isEmpty && ideas.isEmpty && plans.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if isEmpty {
                    EmptyStateView(
                        systemImage: "trash",
                        title: "Nada por aqui",
                        message: "O que vocês excluírem aparece aqui e pode ser restaurado."
                    )
                    .padding(.top, Spacing.xxxl)
                }
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                section("Memórias", items: Array(memories)) { memory in
                    row(title: memory.title, systemImage: memory.memoryCategory.systemImage, deletedAt: memory.deletedAt) {
                        try environment.memories.restore(memory, by: userRecordName)
                    }
                }
                section("Metas", items: Array(goals)) { goal in
                    row(title: goal.title, systemImage: goal.goalCategory.systemImage, deletedAt: goal.deletedAt) {
                        try environment.goals.restore(goal, by: userRecordName)
                    }
                }
                section("Recados", items: Array(notes)) { note in
                    row(title: note.text, systemImage: "envelope", deletedAt: note.deletedAt) {
                        try environment.notes.restore(note, by: userRecordName)
                    }
                }
                section("Lugares", items: Array(places)) { place in
                    row(title: place.name, systemImage: place.placeCategory.systemImage, deletedAt: place.deletedAt) {
                        try environment.places.restore(place, by: userRecordName)
                    }
                }
                section("Lembretes", items: Array(reminders)) { reminder in
                    row(title: reminder.title, systemImage: "bell", deletedAt: reminder.deletedAt) {
                        try environment.reminders.restore(reminder, by: userRecordName)
                        Task { await environment.syncReminderNotifications() }
                    }
                }
                section("Ideias de encontro", items: Array(ideas)) { idea in
                    row(title: idea.title, systemImage: "lightbulb", deletedAt: idea.deletedAt) {
                        try environment.moments.restoreIdea(idea, by: userRecordName)
                    }
                }
                section("Planos de encontro", items: Array(plans)) { plan in
                    row(title: plan.title, systemImage: "calendar", deletedAt: plan.deletedAt) {
                        try environment.moments.restore(plan, by: userRecordName)
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .canvasBackground()
        .navigationTitle("Excluídos recentemente")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section<Item: Identifiable, Row: View>(
        _ title: LocalizedStringKey,
        items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        if !items.isEmpty {
            SectionLabel(title: title)
                .padding(.top, Spacing.xs)
            ForEach(items) { item in
                row(item)
            }
        }
    }

    private func row(title: String?, systemImage: String, deletedAt: Date?, restore: @escaping () throws -> Void) -> some View {
        AdaptiveStack {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.accentText)
                .frame(width: 36, height: 36)
                .background(Palette.surfaceMuted, in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title ?? "")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                if let deletedAt {
                    Text("Excluído \(deletedAt, format: .relative(presentation: .named))")
                        .font(.metadata)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Button("Restaurar") {
                do {
                    try restore()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .buttonStyle(.soft)
        }
        .surfaceCard()
    }
}
