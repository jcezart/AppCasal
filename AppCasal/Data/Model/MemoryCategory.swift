//
//  MemoryCategory.swift
//  AppCasal
//

import Foundation

/// Fixed categories, stored by raw value. Unknown values read as `.other`.
nonisolated enum MemoryCategory: String, CaseIterable, Identifiable, Sendable {
    case date
    case trip
    case beach
    case restaurant
    case celebration
    case special
    case everyday
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: String(localized: "Encontro")
        case .trip: String(localized: "Viagem")
        case .beach: String(localized: "Praia")
        case .restaurant: String(localized: "Restaurante")
        case .celebration: String(localized: "Comemoração")
        case .special: String(localized: "Especial")
        case .everyday: String(localized: "Dia a dia")
        case .other: String(localized: "Outro")
        }
    }

    var systemImage: String {
        switch self {
        case .date: "heart"
        case .trip: "airplane"
        case .beach: "sun.horizon"
        case .restaurant: "fork.knife"
        case .celebration: "party.popper"
        case .special: "sparkles"
        case .everyday: "cup.and.saucer"
        case .other: "tag"
        }
    }
}
