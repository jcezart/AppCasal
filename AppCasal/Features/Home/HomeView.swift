//
//  HomeView.swift
//  AppCasal
//

import CoreData
import SwiftUI

/// Início: couple photo and names, days together, latest note, goal in progress and
/// latest memory.
struct HomeView: View {
    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String
    let showSpace: () -> Void
    let showTab: (AppTab) -> Void

    @FetchRequest private var latestNotes: FetchedResults<Note>
    @FetchRequest private var latestMemories: FetchedResults<Memory>
    @FetchRequest private var activeGoals: FetchedResults<Goal>
    @State private var topInset: CGFloat = 0
    @State private var isCreatingMemory = false
    @State private var errorMessage: String?
    /// Bumped when answers arrive or are sent, so the question card hides once answered.
    @State private var momentsRevision = 0

    init(
        environment: AppEnvironment,
        space: CoupleSpace,
        userRecordName: String,
        showSpace: @escaping () -> Void,
        showTab: @escaping (AppTab) -> Void
    ) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        self.showSpace = showSpace
        self.showTab = showTab
        let notDeleted = NSPredicate(format: "space == %@ AND deletedAt == nil", space)

        let noteRequest = Note.fetchRequest()
        noteRequest.predicate = notDeleted
        noteRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        noteRequest.fetchLimit = 1
        _latestNotes = FetchRequest(fetchRequest: noteRequest)

        let memoryRequest = Memory.fetchRequest()
        memoryRequest.predicate = notDeleted
        memoryRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.date, ascending: false),
            NSSortDescriptor(keyPath: \Memory.createdAt, ascending: false),
        ]
        memoryRequest.fetchLimit = 1
        _latestMemories = FetchRequest(fetchRequest: memoryRequest)

        let goalRequest = Goal.fetchRequest()
        goalRequest.predicate = NSPredicate(format: "space == %@ AND deletedAt == nil AND completedAt == nil", space)
        goalRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Goal.modifiedAt, ascending: false)]
        goalRequest.fetchLimit = 1
        _activeGoals = FetchRequest(fetchRequest: goalRequest)
    }

    var body: some View {
        let _ = momentsRevision
        ScrollView {
            VStack(spacing: 0) {
                CoupleHeroHeader(
                    title: coupleTitle,
                    daysTogether: space.daysTogether(),
                    photoData: space.coverPhotoData,
                    topInset: topInset
                )
                .overlay(alignment: .bottomTrailing) { addCouplePhoto }
                VStack(alignment: .leading, spacing: Spacing.m) {
                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                    if InvitePartner.isPending(environment, space: space, userRecordName: userRecordName) {
                        InvitePartnerCard(environment: environment, space: space)
                    }
                    if MomentsHomeCard.showsOnHome(momentsContext) {
                        MomentsHomeCard(context: momentsContext)
                    }
                    latestNote
                    goalSummary
                    SectionLabel(title: "Última memória")
                        .padding(.top, Spacing.xs)
                    latestMemory
                    Button("Nova memória", systemImage: "plus") { isCreatingMemory = true }
                        .buttonStyle(.primary)
                        .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, space.coverPhotoData == nil ? -Spacing.xxxl * 2 : -Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }
        }
        .ignoresSafeArea(edges: .top)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
        .canvasBackground()
        .sheet(isPresented: $isCreatingMemory) {
            MemoryEditorView(environment: environment, mode: .create(space), userRecordName: userRecordName)
        }
        .navigationDestination(for: MomentsRoute.self) { route in
            MomentsDestination(context: momentsContext, route: route)
        }
        .onAppear { environment.prepareMoments() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: environment.persistence.viewContext)) { notification in
            if MomentsObserver<EmptyView>.touchesArea(notification) { momentsRevision &+= 1 }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: showSpace) {
                    AvatarView(name: me?.displayName ?? "", imageData: me?.avatarData, size: 32)
                }
                .accessibilityLabel(Text("Nosso espaço"))
            }
        }
    }

    /// Without a couple photo, a glass button over the hero invites adding one.
    @ViewBuilder
    private var addCouplePhoto: some View {
        if space.coverPhotoData == nil {
            PhotoPickerButton(onPicked: { photo in
                do {
                    try environment.spaces.setCoverPhoto(photo.imageData, in: space)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }, onFailure: { errorMessage = $0 }, crop: .square) {
                Label("Foto do casal", systemImage: "camera")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.glass)
            .padding(.trailing, Spacing.screen)
            .padding(.bottom, Spacing.xxxl * 2 + Spacing.m)
        }
    }

    @ViewBuilder
    private var latestNote: some View {
        if let note = latestNotes.first {
            Button { showTab(.notes) } label: {
                NotePreviewCard(text: note.text ?? "", authorName: name(for: note.authorID), date: note.createdAt ?? .now)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Abre os recados"))
        } else {
            InfoCard(systemImage: "envelope.open", title: "Nenhum recadinho ainda", message: "O último recadinho entre vocês aparece aqui.")
        }
    }

    @ViewBuilder
    private var goalSummary: some View {
        if let goal = activeGoals.first {
            Button { showTab(.goals) } label: {
                GoalSummaryRow(goal: goal)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Abre as metas"))
        } else {
            InfoCard(systemImage: "target", title: "Nenhuma meta em andamento", message: "Os planos de vocês e o progresso de cada um aparecem aqui.")
        }
    }

    @ViewBuilder
    private var latestMemory: some View {
        if let memory = latestMemories.first {
            NavigationLink {
                MemoryDetailView(environment: environment, memory: memory, userRecordName: userRecordName)
            } label: {
                MemoryRow(memory: memory)
            }
            .buttonStyle(.plain)
        } else {
            InfoCard(systemImage: "photo.on.rectangle.angled", title: "Nenhuma memória ainda", message: "A memória mais recente de vocês aparece aqui.")
        }
    }

    private var me: Member? { environment.spaces.member(for: userRecordName, in: space) }

    private var momentsContext: MomentsContext {
        MomentsContext(environment: environment, space: space, userRecordName: userRecordName)
    }

    private var coupleTitle: String {
        let myName = me?.displayName ?? ""
        guard let partner = environment.spaces.partner(of: userRecordName, in: space)?.displayName else {
            return myName
        }
        return String(localized: "\(myName) e \(partner)", comment: "Couple names, e.g. 'Ana e Lucas'")
    }

    private func name(for userRecordName: String?) -> String {
        space.members?.first { $0.userRecordName == userRecordName }?.displayName ?? String(localized: "Seu par")
    }
}

#if DEBUG
#Preview {
    let environment = DemoData.previewEnvironment()
    NavigationStack {
        HomeView(environment: environment, space: environment.spaces.activeSpace()!, userRecordName: DemoData.ownerID, showSpace: {}, showTab: { _ in })
    }
    .environment(\.managedObjectContext, environment.persistence.viewContext)
}
#endif
