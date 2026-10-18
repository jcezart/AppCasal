//
//  GestureAndReviveViews.swift
//  AppCasal
//

import CoreData
import SwiftUI

// MARK: - Pequeno gesto

/// A small kindness for today. Personal: what was suggested or done stays on this iPhone,
/// so the partner is never told about a surprise. Never sends anything by itself.
struct GestureView: View {
    let context: MomentsContext

    @State private var current: CatalogGesture?
    @State private var didComplete = false
    @State private var isWritingNote = false
    @State private var generator = SystemRandomNumberGenerator()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                MomentsHeader(systemImage: "hand.wave", title: "Pequeno gesto", message: "Uma sugestão simples, sem obrigação e sem esperar nada em troca.")
                if let current {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(current.text)
                            .font(.noteQuote)
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label("Cerca de \(current.durationMinutes) min", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                        if current.remoteFriendly {
                            Label("Dá para fazer à distância", systemImage: "video")
                                .font(.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .surfaceCard()
                    if didComplete {
                        Label("Que bom! Fica guardado só neste iPhone.", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Palette.success)
                        Button("Outra sugestão") { pick() }
                            .buttonStyle(.soft)
                    } else {
                        Button {
                            context.local.noteGestureDone(current.id)
                            didComplete = true
                        } label: {
                            Text("Feito")
                        }
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("gesture.done")
                        if mentionsMessage(current) {
                            Button {
                                isWritingNote = true
                            } label: {
                                Label("Escrever um recadinho", systemImage: "square.and.pencil")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.soft)
                        }
                        Button("Trocar sugestão") { pick() }
                            .buttonStyle(.text)
                            .accessibilityIdentifier("gesture.swap")
                    }
                } else if case .failure = context.environment.catalog {
                    ErrorBanner(message: String(localized: "O conteúdo desta área não pôde ser carregado."))
                }
            }
            .padding(Spacing.screen)
        }
        .canvasBackground()
        .navigationTitle("Pequeno gesto")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard current == nil, case .success(let catalog) = context.environment.catalog else { return }
            if let id = context.local.currentGesture, let saved = catalog.gesture(withID: id) {
                current = saved
            } else {
                pick()
            }
        }
        .sheet(isPresented: $isWritingNote) {
            // The person writes and sends the note; nothing is sent on their behalf.
            NoteComposerView(environment: context.environment, space: context.space, userRecordName: context.userRecordName, mode: .new)
        }
    }

    private func mentionsMessage(_ gesture: CatalogGesture) -> Bool {
        let text = gesture.text.lowercased()
        return text.contains("mensagem") || text.contains("recado") || text.contains("bilhete")
    }

    private func pick() {
        guard case .success(let catalog) = context.environment.catalog else { return }
        let next = GestureRules.next(from: catalog.gestures, recent: context.local.recentGestures, excluding: current?.id, using: &generator)
        if let next {
            context.local.noteGestureShown(next.id)
            context.local.currentGesture = next.id
        }
        current = next
        didComplete = false
    }
}

// MARK: - Vamos reviver?

/// A real memory of the couple, to remember and maybe relive a part of it. Never changes
/// the original memory; reliving it creates a new memory only on "Salvar".
struct ReviveView: View {
    let context: MomentsContext

    @State private var currentID: UUID?
    @State private var yearsAgo: Int?
    @State private var isReliving = false

    var body: some View {
        MomentsObserver(context: context.environment.persistence.viewContext) {
            content
        }
        .canvasBackground()
        .navigationTitle("Vamos reviver?")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if currentID == nil { suggest() } }
        .sheet(isPresented: $isReliving) {
            if let memory {
                MemoryEditorView(
                    environment: context.environment,
                    mode: .create(context.space),
                    userRecordName: context.userRecordName,
                    prefill: relivingDraft(of: memory),
                    onSaved: { saved in try? context.environment.memories.setRevisit(of: memory.id, on: saved) }
                )
            }
        }
    }

    private var memories: [Memory] {
        (context.space.memories ?? []).filter { $0.deletedAt == nil && $0.date != nil }
    }

    private var memory: Memory? {
        memories.first { $0.id == currentID }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                MomentsHeader(systemImage: "arrow.counterclockwise.heart", title: "Vamos reviver?", message: "Uma memória de vocês para lembrar juntos e, quem sabe, repetir um pedaço.")
                if let memory {
                    if let yearsAgo {
                        StatusChip(title: yearsAgo == 1 ? "Há 1 ano, neste dia" : "Há \(yearsAgo) anos, neste dia", systemImage: "calendar")
                    }
                    MemoryRow(memory: memory)
                    Text("Que tal repetir uma parte desse dia? Voltem ao lugar, refaçam o prato ou ouçam a mesma música.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                    if let id = memory.id {
                        NavigationLink(value: MomentsRoute.memory(id)) {
                            Text("Ver memória")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.soft)
                    }
                    Button {
                        isReliving = true
                    } label: {
                        Text("Reviver esse momento")
                    }
                    .buttonStyle(.primary)
                    Button("Outra memória") { suggest(skipping: memory.id) }
                        .buttonStyle(.text)
                } else {
                    EmptyStateView(
                        systemImage: "photo.on.rectangle.angled",
                        title: "Ainda não há o que reviver",
                        message: "As memórias que vocês guardarem voltam aqui depois de algumas semanas, e no aniversário de cada uma."
                    )
                    .padding(.top, Spacing.xl)
                }
            }
            .padding(Spacing.screen)
        }
    }

    private func suggest(skipping id: UUID? = nil) {
        let candidates = memories.compactMap { memory -> ReviveCandidate? in
            guard let id = memory.id, let date = memory.date else { return nil }
            return ReviveCandidate(id: id, date: date)
        }
        let recent = context.local.recentRevives + (id.map { [$0] } ?? [])
        let suggestion = ReviveRules.suggestion(from: candidates, recent: recent, today: .now, calendar: .current)
        currentID = suggestion?.id
        yearsAgo = suggestion?.yearsAgo
        if let id = suggestion?.id {
            context.local.noteReviveShown(id)
        }
    }

    private func relivingDraft(of memory: Memory) -> MemoryDraft {
        var draft = MemoryDraft()
        draft.title = String(localized: "De novo: \(memory.title ?? "")")
        draft.category = memory.memoryCategory
        if let name = memory.locationName, let latitude = memory.latitude?.doubleValue, let longitude = memory.longitude?.doubleValue {
            draft.place = PlaceLink(placeID: memory.placeID, name: name, latitude: latitude, longitude: longitude)
        }
        return draft
    }
}
