//
//  MapTabView.swift
//  AppCasal
//

import CoreData
import MapKit
import SwiftUI

/// Mapa: visited and wished places, search, filters, distance, directions and
/// registering a visit as a memory. Floating controls use Liquid Glass because they sit
/// over changing map content.
struct MapTabView: View {
    enum Filter: Hashable, CaseIterable {
        case all
        case visited
        case wishlist

        var title: LocalizedStringKey {
            switch self {
            case .all: "Todos"
            case .visited: "Visitados"
            case .wishlist: "Queremos ir"
            }
        }
    }

    let environment: AppEnvironment
    @ObservedObject var space: CoupleSpace
    let userRecordName: String

    @FetchRequest private var places: FetchedResults<Place>
    @State private var filter = Filter.all
    @State private var position = MapCameraPosition.automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedID: UUID?
    @State private var isSearching = false

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        _places = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Place.createdAt, ascending: true)],
            predicate: NSPredicate(format: "space == %@ AND deletedAt == nil", space),
            animation: .default
        )
    }

    private var filtered: [Place] {
        places.filter { place in
            switch filter {
            case .all: true
            case .visited: place.placeStatus == .visited
            case .wishlist: place.placeStatus == .wishlist
            }
        }
    }

    private var selectedPlace: Binding<Place?> {
        Binding(
            get: { selectedID.flatMap { id in places.first { $0.id == id } } },
            set: { selectedID = $0?.id }
        )
    }

    var body: some View {
        Map(position: $position, selection: $selectedID) {
            ForEach(filtered) { place in
                if let id = place.id {
                    Marker(place.name ?? "", systemImage: markerSymbol(for: place), coordinate: place.coordinate)
                        .tint(place.placeStatus == .visited ? Palette.accent : Palette.accentText)
                        .tag(id)
                }
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { visibleRegion = $0.region }
        .safeAreaInset(edge: .top) { topControls }
        .safeAreaInset(edge: .bottom) { bottomContent }
        .toolbar(.hidden, for: .navigationBar)
        .task { await environment.location.updateLocation() }
        .sheet(item: selectedPlace) { place in
            PlaceDetailView(environment: environment, space: space, place: place, userRecordName: userRecordName)
                .presentationDetents([.height(320), .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .height(320)))
        }
        .sheet(isPresented: $isSearching) {
            PlaceSearchView(environment: environment, space: space, userRecordName: userRecordName, region: visibleRegion) { place in
                position = .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
            }
        }
    }

    private func markerSymbol(for place: Place) -> String {
        place.placeStatus == .visited ? place.placeCategory.systemImage : "bookmark.fill"
    }

    private var topControls: some View {
        GlassEffectContainer(spacing: Spacing.xs) {
            VStack(spacing: Spacing.xs) {
                Button { isSearching = true } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                        Text("Buscar um lugar")
                        Spacer()
                    }
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: 44)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityIdentifier("map.search")
                HStack(spacing: Spacing.xs) {
                    ForEach(Filter.allCases, id: \.self) { option in
                        filterButton(option)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.xs)
    }

    private func filterButton(_ option: Filter) -> some View {
        let isSelected = option == filter
        return Button {
            filter = option
        } label: {
            Text(option.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Palette.onAccent : Palette.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(Palette.accent).interactive() : .regular.interactive(), in: .capsule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var bottomContent: some View {
        HStack(alignment: .bottom) {
            if places.isEmpty {
                InfoCard(
                    systemImage: "mappin.and.ellipse",
                    title: "Nenhum lugar salvo ainda",
                    message: "Busque um lugar para guardar onde vocês foram ou querem ir."
                )
            } else {
                Spacer()
            }
            Button("Adicionar lugar", systemImage: "plus") { isSearching = true }
                .labelStyle(.iconOnly)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(Palette.accent)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.xs)
    }
}

/// Bottom sheet for a place: status, distance, note, directions and visit.
struct PlaceDetailView: View {
    let environment: AppEnvironment
    let space: CoupleSpace
    @ObservedObject var place: Place
    let userRecordName: String

    @Environment(\.dismiss) private var dismiss
    @State private var isRegisteringVisit = false
    @State private var isEditing = false
    @State private var errorMessage: String?

    private var linkedMemory: Memory? {
        guard let memoryID = place.memoryID else { return nil }
        return space.memories?.first { $0.id == memoryID && $0.deletedAt == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(place.name ?? "")
                                .font(.sectionTitle)
                                .foregroundStyle(Palette.textPrimary)
                            HStack(spacing: Spacing.xs) {
                                StatusChip(
                                    title: LocalizedStringKey(place.placeStatus.title),
                                    systemImage: place.placeStatus.systemImage,
                                    tone: place.placeStatus == .visited ? .success : .accent
                                )
                                TagChip(title: place.placeCategory.title, systemImage: place.placeCategory.systemImage)
                            }
                        }
                        Spacer()
                        Menu {
                            Button("Editar", systemImage: "pencil") { isEditing = true }
                            Button("Excluir", systemImage: "trash", role: .destructive) {
                                perform { try environment.places.softDelete(place, by: userRecordName) }
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                                .contentShape(.rect)
                        }
                        .accessibilityLabel(Text("Opções do lugar"))
                    }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        if let address = place.address {
                            Text(address)
                        }
                        if let distance = environment.location.distance(to: place.coordinate) {
                            Text("A \(distance, format: .measurement(width: .abbreviated, usage: .road)) de você")
                        }
                        if let visitedAt = place.visitedAt, place.placeStatus == .visited {
                            Text("Visitado em \(visitedAt, format: .dateTime.day().month(.wide).year())")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    if let note = place.note {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                    HStack(spacing: Spacing.s) {
                        Button("Como chegar", systemImage: "location.fill") {
                            Directions.open(name: place.name ?? "", coordinate: place.coordinate)
                        }
                        .buttonStyle(.soft)
                        if let linkedMemory {
                            NavigationLink {
                                MemoryDetailView(environment: environment, memory: linkedMemory, userRecordName: userRecordName)
                            } label: {
                                Label("Ver memória", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.primary)
                        } else {
                            Button(place.placeStatus == .visited ? "Criar memória" : "Registrar visita", systemImage: "checkmark") {
                                isRegisteringVisit = true
                            }
                            .buttonStyle(.primary)
                        }
                    }
                }
                .padding(Spacing.screen)
            }
            .canvasBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isRegisteringVisit) {
            MemoryEditorView(environment: environment, mode: .create(space), userRecordName: userRecordName, visit: place)
        }
        .sheet(isPresented: $isEditing) {
            EditPlaceView(environment: environment, place: place, userRecordName: userRecordName)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditPlaceView: View {
    let environment: AppEnvironment
    let place: Place
    let userRecordName: String

    @Environment(\.dismiss) private var dismiss
    @State private var status: PlaceStatus
    @State private var category: MemoryCategory
    @State private var note: String
    @State private var errorMessage: String?

    init(environment: AppEnvironment, place: Place, userRecordName: String) {
        self.environment = environment
        self.place = place
        self.userRecordName = userRecordName
        _status = State(initialValue: place.placeStatus)
        _category = State(initialValue: place.placeCategory)
        _note = State(initialValue: place.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Situação", selection: $status) {
                        ForEach(PlaceStatus.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Categoria", selection: $category) {
                        ForEach(MemoryCategory.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) }
                    }
                    TextField("Uma nota (opcional)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                .listRowBackground(Palette.surface)
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Palette.accentText) }
                        .listRowBackground(Palette.surface)
                }
            }
            .canvasBackground()
            .tint(Palette.accentText)
            .navigationTitle(place.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        do {
                            try environment.places.update(place, category: category, status: status, note: note, by: userRecordName)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
    }
}
