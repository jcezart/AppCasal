//
//  Categories.swift
//  AppCasal
//

import Foundation

nonisolated enum PlaceStatus: String, CaseIterable, Identifiable, Sendable {
    case wishlist
    case visited

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wishlist: String(localized: "Queremos ir")
        case .visited: String(localized: "Visitado")
        }
    }

    var systemImage: String {
        switch self {
        case .wishlist: "bookmark.fill"
        case .visited: "checkmark.circle.fill"
        }
    }
}

/// Fixed goal categories, stored by raw value. Unknown values read as `.other`.
nonisolated enum GoalCategory: String, CaseIterable, Identifiable, Sendable {
    case trip
    case relationship
    case home
    case finances
    case health
    case celebration
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trip: String(localized: "Viagem")
        case .relationship: String(localized: "Relacionamento")
        case .home: String(localized: "Casa")
        case .finances: String(localized: "Finanças")
        case .health: String(localized: "Saúde")
        case .celebration: String(localized: "Comemoração")
        case .other: String(localized: "Outro")
        }
    }

    var systemImage: String {
        switch self {
        case .trip: "airplane"
        case .relationship: "heart"
        case .home: "house"
        case .finances: "banknote"
        case .health: "figure.walk"
        case .celebration: "party.popper"
        case .other: "target"
        }
    }
}
