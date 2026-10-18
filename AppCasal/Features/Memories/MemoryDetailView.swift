//
//  MemoryDetailView.swift
//  AppCasal
//

import SwiftUI

struct MemoryDetailView: View {
    let environment: AppEnvironment
    @ObservedObject var memory: Memory
    let userRecordName: String

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                photos
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(memory.title ?? "")
                        .font(.displayTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    AdaptiveStack(spacing: Spacing.xs) {
                        Label {
                            Text(memory.date ?? .now, format: .dateTime.day().month(.wide).year())
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        TagChip(title: memory.memoryCategory.title, systemImage: memory.memoryCategory.systemImage)
                    }
                    if let location = memory.locationName,
                       let latitude = memory.latitude?.doubleValue, let longitude = memory.longitude?.doubleValue {
                        Button {
                            Directions.open(name: location, coordinate: .init(latitude: latitude, longitude: longitude))
                        } label: {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                        }
                        .buttonStyle(.soft)
                        .accessibilityHint(Text("Abre o Mapas com o caminho"))
                    }
                    if let details = memory.details {
                        Text(details)
                            .font(.body)
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.top, Spacing.xs)
                    }
                    Text(authorship)
                        .font(.metadata)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, Spacing.s)
                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                }
                .padding(.horizontal, Spacing.screen)
            }
            .padding(.bottom, Spacing.xl)
        }
        .canvasBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Editar", systemImage: "pencil") { isEditing = true }
                    Button("Excluir", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                } label: {
                    Label("Opções da memória", systemImage: "ellipsis")
                }
                .accessibilityIdentifier("memoryDetail.menu")
            }
        }
        .confirmationDialog("Excluir esta memória?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Excluir", role: .destructive, action: delete)
        } message: {
            Text("Ela vai para Excluídos recentemente, de onde vocês podem restaurá-la.")
        }
        .sheet(isPresented: $isEditing) {
            MemoryEditorView(environment: environment, mode: .edit(memory), userRecordName: userRecordName)
        }
    }

    @ViewBuilder
    private var photos: some View {
        let photos = memory.visiblePhotos
        if !photos.isEmpty {
            TabView {
                ForEach(photos) { photo in
                    PhotoView(photo: photo, usesThumbnail: false)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(.rect(cornerRadius: Radius.photo, style: .continuous))
            .padding(.horizontal, Spacing.screen)
            .accessibilityElement()
            .accessibilityLabel(Text("\(photos.count) fotos"))
        }
    }

    private var authorship: String {
        let members = memory.space?.members ?? []
        let author = members.first { $0.userRecordName == memory.createdBy }?.displayName ?? String(localized: "Seu par")
        guard let modifiedBy = memory.modifiedBy, modifiedBy != memory.createdBy,
              let editor = members.first(where: { $0.userRecordName == modifiedBy })?.displayName else {
            return String(localized: "Guardada por \(author)")
        }
        return String(localized: "Guardada por \(author) · editada por \(editor)")
    }

    private func delete() {
        do {
            try environment.memories.softDelete(memory, by: userRecordName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
