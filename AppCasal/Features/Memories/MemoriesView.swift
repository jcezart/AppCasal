//
//  MemoriesView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Memórias: the couple's timeline, newest first, grouped by month.
struct MemoriesView: View {
    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @FetchRequest private var memories: FetchedResults<Memory>
    @State private var isCreating = false
    @State private var isShowingDeleted = false

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        _memories = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Memory.date, ascending: false),
                NSSortDescriptor(keyPath: \Memory.createdAt, ascending: false),
            ],
            predicate: NSPredicate(format: "space == %@ AND deletedAt == nil", space),
            animation: .default
        )
    }

    var body: some View {
        ScrollView {
            if memories.isEmpty {
                EmptyStateView(
                    systemImage: "photo.on.rectangle.angled",
                    title: "Nenhuma memória ainda",
                    message: "Guardem aqui os momentos de vocês, com fotos, data e descrição.",
                    actionTitle: "Nova memória",
                    action: { isCreating = true }
                )
                .padding(.top, Spacing.xxxl)
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.m, pinnedViews: []) {
                    ForEach(MonthSection.group(Array(memories))) { section in
                        Text(section.title)
                            .font(.sectionTitle)
                            .foregroundStyle(Palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, Spacing.xs)
                        ForEach(section.memories) { memory in
                            NavigationLink {
                                MemoryDetailView(environment: environment, memory: memory, userRecordName: userRecordName)
                            } label: {
                                MemoryCard(memory: memory)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("memories.card")
                        }
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.xl)
            }
        }
        .canvasBackground()
        .navigationTitle("Memórias")
        .navigationSubtitle("Nossos momentos, para sempre.")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Excluídos recentemente", systemImage: "trash") { isShowingDeleted = true }
                } label: {
                    Label("Mais opções", systemImage: "ellipsis")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nova memória", systemImage: "plus") { isCreating = true }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("memories.add")
            }
        }
        .sheet(isPresented: $isCreating) {
            MemoryEditorView(environment: environment, mode: .create(space), userRecordName: userRecordName)
        }
        .sheet(isPresented: $isShowingDeleted) {
            NavigationStack {
                DeletedItemsView(environment: environment, space: space, userRecordName: userRecordName)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Concluído", systemImage: "checkmark", role: .confirm) { isShowingDeleted = false }
                        }
                    }
            }
        }
    }
}

/// Memories of one calendar month, for the timeline headers.
struct MonthSection: Identifiable {
    let id: Date
    let title: String
    let memories: [Memory]

    static func group(_ memories: [Memory], calendar: Calendar = .current) -> [MonthSection] {
        var sections: [MonthSection] = []
        for memory in memories {
            let date = memory.date ?? .distantPast
            let month = calendar.dateInterval(of: .month, for: date)?.start ?? date
            if sections.last?.id == month {
                let last = sections.removeLast()
                sections.append(MonthSection(id: month, title: last.title, memories: last.memories + [memory]))
            } else {
                sections.append(MonthSection(id: month, title: title(for: month), memories: [memory]))
            }
        }
        return sections
    }

    /// "Outubro de 2026": only the first letter is capitalized.
    static func title(for month: Date) -> String {
        let text = month.formatted(.dateTime.month(.wide).year())
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

#if DEBUG
#Preview {
    let environment = DemoData.previewEnvironment()
    NavigationStack {
        MemoriesView(environment: environment, space: environment.spaces.activeSpace()!, userRecordName: DemoData.ownerID)
    }
    .environment(\.managedObjectContext, environment.persistence.viewContext)
}
#endif
