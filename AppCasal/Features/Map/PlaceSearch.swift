//
//  PlaceSearch.swift
//  AppCasal
//

import MapKit
import SwiftUI

/// A search result reduced to plain values.
nonisolated struct PlaceSearchResult: Identifiable, Sendable, Equatable {
    let id = UUID()
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let category: MemoryCategory

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Searches places and points of interest with MapKit, biased to a region.
nonisolated enum PlaceSearch {
    @concurrent
    static func search(_ query: String, near region: MKCoordinateRegion?) async throws -> [PlaceSearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let region {
            request.region = region
        }
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.map { item in
            PlaceSearchResult(
                name: item.name ?? query,
                address: item.address?.shortAddress ?? item.address?.fullAddress,
                latitude: item.location.coordinate.latitude,
                longitude: item.location.coordinate.longitude,
                category: category(for: item.pointOfInterestCategory)
            )
        }
    }

    static func category(for poi: MKPointOfInterestCategory?) -> MemoryCategory {
        switch poi {
        case .restaurant?, .cafe?, .bakery?, .brewery?, .winery?, .foodMarket?: .restaurant
        case .beach?: .beach
        case .airport?, .hotel?, .campground?, .nationalPark?: .trip
        case .nightlife?, .theater?, .movieTheater?, .musicVenue?: .date
        default: .other
        }
    }
}

/// Opens Apple Maps with directions to a place.
enum Directions {
    static func open(name: String, coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}

/// Search sheet: type a place, pick a result, choose status and save it.
struct PlaceSearchView: View {
    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String
    let region: MKCoordinateRegion?
    let onSaved: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Palette.accentText)
                }
                ForEach(results) { result in
                    NavigationLink {
                        AddPlaceView(environment: environment, space: space, userRecordName: userRecordName, result: result) { place in
                            onSaved(place)
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .foregroundStyle(Palette.textPrimary)
                            if let address = result.address {
                                Text(address)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            if let distance = environment.location.distance(to: result.coordinate) {
                                Text(distance, format: .measurement(width: .abbreviated, usage: .road))
                                    .font(.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .overlay {
                if isSearching {
                    ProgressView()
                } else if results.isEmpty, !query.isEmpty, errorMessage == nil {
                    EmptyStateView(systemImage: "magnifyingglass", title: "Nenhum resultado", message: "Tente outro nome ou endereço.")
                } else if query.isEmpty {
                    EmptyStateView(systemImage: "mappin.and.ellipse", title: "Buscar um lugar", message: "Restaurantes, praias, endereços… tudo o que vocês viveram ou querem viver.")
                }
            }
            .canvasBackground()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Buscar um lugar"))
            .task(id: query) { await search() }
            .navigationTitle("Novo lugar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
    }

    /// Debounced: restarts on every keystroke and runs after a short pause.
    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            results = []
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(350))
        } catch {
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await PlaceSearch.search(text, near: region)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            results = []
            errorMessage = String(localized: "Não foi possível buscar agora. Verifique a conexão.")
        }
    }
}

/// Status, category and note for a place found in search.
private struct AddPlaceView: View {
    let environment: AppEnvironment
    let space: CoupleSpace
    let userRecordName: String
    let result: PlaceSearchResult
    let onSaved: (Place) -> Void

    @State private var status = PlaceStatus.wishlist
    @State private var category: MemoryCategory
    @State private var note = ""
    @State private var errorMessage: String?

    init(environment: AppEnvironment, space: CoupleSpace, userRecordName: String, result: PlaceSearchResult, onSaved: @escaping (Place) -> Void) {
        self.environment = environment
        self.space = space
        self.userRecordName = userRecordName
        self.result = result
        self.onSaved = onSaved
        _category = State(initialValue: result.category)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(result.name).font(.cardTitle)
                    if let address = result.address {
                        Text(address).font(.footnote).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .listRowBackground(Palette.surface)
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
        .navigationTitle("Salvar lugar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar", systemImage: "checkmark", role: .confirm) {
                    do {
                        let place = try environment.places.create(
                            PlaceDraft(name: result.name, address: result.address, latitude: result.latitude, longitude: result.longitude, category: category, status: status, note: note),
                            in: space,
                            by: userRecordName
                        )
                        onSaved(place)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
