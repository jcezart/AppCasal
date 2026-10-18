//
//  MemoryEditorView.swift
//  AppCasal
//

import CoreData
import PhotosUI
import SwiftUI

/// Creates or edits a memory: title, date, category, description and photos.
struct MemoryEditorView: View {
    enum Mode {
        case create(CoupleSpace)
        case edit(Memory)
    }

    /// A photo picked in this session, already downscaled.
    private struct PendingPhoto: Identifiable {
        let id = UUID()
        let processed: ProcessedPhoto
        let preview: UIImage?
    }

    let environment: AppEnvironment
    let mode: Mode
    let userRecordName: String
    /// Saved place whose visit this new memory registers.
    let visit: Place?
    /// Called once the memory is saved (links it to a discovery, a date or a revisit).
    let onSaved: ((Memory) -> Void)?

    static let maximumPhotos = 10

    @Environment(\.dismiss) private var dismiss
    @State private var draft: MemoryDraft
    @State private var existingPhotos: [MemoryPhoto]
    @State private var removedPhotoIDs: Set<NSManagedObjectID> = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var processingCount = 0
    @State private var errorMessage: String?
    @State private var isConfirmingDiscard = false
    /// Blocks a second save from a double tap before the sheet closes.
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, details }

    private let initialDraft: MemoryDraft

    /// `prefill` starts a new memory with suggested values; nothing is saved until "Salvar".
    init(
        environment: AppEnvironment,
        mode: Mode,
        userRecordName: String,
        visit: Place? = nil,
        prefill: MemoryDraft? = nil,
        onSaved: ((Memory) -> Void)? = nil
    ) {
        self.environment = environment
        self.mode = mode
        self.userRecordName = userRecordName
        self.visit = visit
        self.onSaved = onSaved
        var draft = MemoryDraft()
        var photos: [MemoryPhoto] = []
        if case .edit(let memory) = mode {
            draft.title = memory.title ?? ""
            draft.details = memory.details ?? ""
            draft.date = memory.date ?? .now
            draft.category = memory.memoryCategory
            if let name = memory.locationName, let latitude = memory.latitude?.doubleValue, let longitude = memory.longitude?.doubleValue {
                draft.place = PlaceLink(placeID: memory.placeID, name: name, latitude: latitude, longitude: longitude)
            }
            photos = memory.visiblePhotos
        } else if let visit {
            draft.title = visit.name ?? ""
            draft.category = visit.placeCategory
            draft.place = PlaceLink(placeID: visit.id, name: visit.name ?? "", latitude: visit.latitude, longitude: visit.longitude)
        }
        if case .create = mode, let prefill {
            let place = draft.place
            draft = prefill
            draft.place = prefill.place ?? place
        }
        initialDraft = draft
        _draft = State(initialValue: draft)
        _existingPhotos = State(initialValue: photos)
    }

    private var placeSpace: CoupleSpace? {
        switch mode {
        case .create(let space): space
        case .edit(let memory): memory.space
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var keptPhotos: [MemoryPhoto] {
        existingPhotos.filter { !removedPhotoIDs.contains($0.objectID) }
    }

    private var photoCount: Int { keptPhotos.count + pendingPhotos.count }

    private var hasChanges: Bool {
        draft != initialDraft || !removedPhotoIDs.isEmpty || !pendingPhotos.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $draft.title)
                        .font(.cardTitle)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .details }
                        .accessibilityIdentifier("memoryEditor.title")
                    DatePicker("Data", selection: $draft.date, in: ...Date.now, displayedComponents: .date)
                    Picker("Categoria", selection: $draft.category) {
                        ForEach(MemoryCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage).tag(category)
                        }
                    }
                    NavigationLink {
                        MemoryPlacePicker(space: placeSpace, selection: $draft.place)
                    } label: {
                        LabeledContent("Lugar", value: draft.place?.name ?? String(localized: "Nenhum"))
                    }
                }
                .listRowBackground(Palette.surface)
                Section("Descrição") {
                    TextField("O que vocês viveram nesse dia?", text: $draft.details, axis: .vertical)
                        .lineLimit(3...10)
                        .focused($focusedField, equals: .details)
                        .accessibilityIdentifier("memoryEditor.details")
                }
                .listRowBackground(Palette.surface)
                Section {
                    photoStrip
                } header: {
                    Text("Fotos")
                } footer: {
                    Text("Até \(Self.maximumPhotos) fotos. Elas são reduzidas para ocupar menos espaço no iCloud.")
                }
                .listRowBackground(Palette.surface)
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(Palette.accentText)
                    }
                    .listRowBackground(Palette.surface)
                }
            }
            .canvasBackground()
            .tint(Palette.accentText)
            .navigationTitle(isEditing ? "Editar memória" : "Nova memória")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) {
                        if hasChanges { isConfirmingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", systemImage: "checkmark", role: .confirm, action: save)
                        .confirmationButtonStyle()
                        .disabled(!draft.isValid || processingCount > 0 || isSaving)
                        .accessibilityIdentifier("memoryEditor.save")
                }
            }
            .confirmationDialog("Descartar alterações?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) { dismiss() }
                Button("Continuar editando", role: .cancel) {}
            }
            .interactiveDismissDisabled(hasChanges)
            .onChange(of: pickerItems) { loadPickedPhotos() }
            .onAppear {
                if !isEditing { focusedField = .title }
            }
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                ForEach(keptPhotos) { photo in
                    thumbnail { PhotoView(photo: photo) } remove: {
                        removedPhotoIDs.insert(photo.objectID)
                    }
                }
                ForEach(pendingPhotos) { pending in
                    thumbnail {
                        if let preview = pending.preview {
                            Image(uiImage: preview).resizable().scaledToFill()
                        } else {
                            Palette.surfaceMuted
                        }
                    } remove: {
                        pendingPhotos.removeAll { $0.id == pending.id }
                    }
                }
                ForEach(0..<processingCount, id: \.self) { _ in
                    ProgressView()
                        .frame(width: 88, height: 88)
                        .background(Palette.surfaceMuted, in: .rect(cornerRadius: Radius.photo, style: .continuous))
                }
                if photoCount + processingCount < Self.maximumPhotos {
                    // The picker label is a Sendable closure; capture the colors here.
                    let tint = Palette.accentText
                    let fill = Palette.surfaceMuted
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: Self.maximumPhotos - photoCount - processingCount,
                        matching: .images
                    ) {
                        VStack(spacing: Spacing.xxs) {
                            Image(systemName: "plus")
                                .font(.title3)
                            Text("Adicionar")
                                .font(.caption)
                        }
                        .foregroundStyle(tint)
                        .frame(width: 88, height: 88)
                        .background(fill, in: .rect(cornerRadius: Radius.photo, style: .continuous))
                    }
                    .buttonStyle(.tile)
                    .accessibilityLabel(Text("Adicionar fotos"))
                }
            }
            .padding(.vertical, Spacing.xxs)
        }
        .scrollIndicators(.hidden)
    }

    private func thumbnail<Content: View>(@ViewBuilder content: () -> Content, remove: @escaping () -> Void) -> some View {
        content()
            .frame(width: 88, height: 88)
            .clipShape(.rect(cornerRadius: Radius.photo, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Palette.onAccent, Palette.textPrimary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(Spacing.xxs)
                .accessibilityLabel(Text("Remover foto"))
            }
    }

    private func loadPickedPhotos() {
        let items = pickerItems
        guard !items.isEmpty else { return }
        pickerItems = []
        processingCount += items.count
        Task {
            var failures = 0
            for item in items {
                defer { processingCount -= 1 }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        failures += 1
                        continue
                    }
                    let processed = try await PhotoProcessing.process(data)
                    let preview = UIImage(data: processed.thumbnailData)
                    pendingPhotos.append(PendingPhoto(processed: processed, preview: preview))
                } catch {
                    failures += 1
                }
            }
            errorMessage = failures > 0
                ? String(localized: "Não foi possível adicionar \(failures) foto(s).")
                : nil
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        do {
            switch mode {
            case .create(let space):
                let memory = try environment.memories.create(
                    draft,
                    photos: pendingPhotos.map(\.processed),
                    in: space,
                    by: userRecordName
                )
                if let visit {
                    try environment.places.markVisited(visit, memoryID: memory.id, on: draft.date, by: userRecordName)
                }
                onSaved?(memory)
            case .edit(let memory):
                try environment.memories.update(
                    memory,
                    with: draft,
                    removing: removedPhotoIDs,
                    adding: pendingPhotos.map(\.processed),
                    by: userRecordName
                )
            }
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

/// Chooses one of the couple's saved places for a memory, or none.
private struct MemoryPlacePicker: View {
    let space: CoupleSpace?
    @Binding var selection: PlaceLink?

    @Environment(\.dismiss) private var dismiss

    private var places: [Place] {
        (space?.places ?? [])
            .filter { $0.deletedAt == nil }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                row(title: String(localized: "Nenhum"), subtitle: nil, isSelected: selection == nil) {
                    selection = nil
                }
                if let selection, selection.placeID == nil || !places.contains(where: { $0.id == selection.placeID }) {
                    row(title: selection.name, subtitle: nil, isSelected: true) {}
                }
                ForEach(places) { place in
                    row(title: place.name ?? "", subtitle: place.address, isSelected: selection?.placeID == place.id) {
                        selection = PlaceLink(placeID: place.id, name: place.name ?? "", latitude: place.latitude, longitude: place.longitude)
                    }
                }
            } footer: {
                Text("Para outro lugar, salve-o antes pela busca no Mapa.")
            }
            .listRowBackground(Palette.surface)
        }
        .canvasBackground()
        .navigationTitle("Lugar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Palette.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(.footnote).foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(Palette.accentText)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
