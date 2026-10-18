//
//  DateIdeas.swift
//  AppCasal
//

import Foundation

/// Something the couple could do together, from one of three sources.
nonisolated struct DateCandidate: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case catalog
        case place
        case idea

        var title: String {
            switch self {
            case .catalog: String(localized: "Ideias do app")
            case .place: String(localized: "Queremos ir")
            case .idea: String(localized: "Nossas ideias")
            }
        }
    }

    let kind: Kind
    /// Catalog ID, place UUID or idea UUID.
    let sourceID: String
    let title: String
    let details: String?
    let location: DateLocation?
    let cost: DateCost
    /// Nil when unknown ("a confirmar").
    let durationMinutes: Int?
    let remoteFriendly: Bool
    let materials: [String]
    let costNote: String?

    var id: String { "\(kind.rawValue):\(sourceID)" }

    init(
        kind: Kind,
        sourceID: String,
        title: String,
        details: String?,
        location: DateLocation?,
        cost: DateCost,
        durationMinutes: Int?,
        remoteFriendly: Bool,
        materials: [String] = [],
        costNote: String? = nil
    ) {
        self.kind = kind
        self.sourceID = sourceID
        self.title = title
        self.details = details
        self.location = location
        self.cost = cost
        self.durationMinutes = durationMinutes
        self.remoteFriendly = remoteFriendly
        self.materials = materials
        self.costNote = costNote
    }

    init(_ date: CatalogDate) {
        self.init(
            kind: .catalog,
            sourceID: date.id,
            title: date.title,
            details: date.description,
            location: date.location,
            cost: date.costTier,
            durationMinutes: date.durationMinutes,
            remoteFriendly: date.remoteFriendly,
            materials: date.materials,
            costNote: date.costNote
        )
    }

    /// A saved "Queremos ir" place: out of home, physical, cost and duration unknown.
    init(placeID: UUID, name: String, note: String?) {
        self.init(
            kind: .place,
            sourceID: placeID.uuidString,
            title: name,
            details: note,
            location: .fora,
            cost: .aConfirmar,
            durationMinutes: nil,
            remoteFriendly: false
        )
    }
}

nonisolated enum LocationFilter: String, CaseIterable, Sendable {
    case any, home, out

    var title: String {
        switch self {
        case .any: String(localized: "Qualquer lugar")
        case .home: String(localized: "Em casa")
        case .out: String(localized: "Fora de casa")
        }
    }
}

nonisolated enum CostFilter: String, CaseIterable, Sendable {
    /// Includes variable and unconfirmed costs: choosing it accepts them.
    case any
    case noExtraCost
    case upToLow

    var title: String {
        switch self {
        case .any: String(localized: "Qualquer custo, inclusive a confirmar")
        case .noExtraCost: String(localized: "Sem gasto adicional")
        case .upToLow: String(localized: "Até custo baixo")
        }
    }
}

nonisolated enum DurationFilter: Int, CaseIterable, Sendable {
    case any = 0
    case upTo30 = 30
    case upTo60 = 60
    case upTo120 = 120

    var title: String {
        switch self {
        case .any: String(localized: "Qualquer duração")
        case .upTo30: String(localized: "Até 30 min")
        case .upTo60: String(localized: "Até 1 hora")
        case .upTo120: String(localized: "Até 2 horas")
        }
    }
}

/// Independent filters. Unknown values never pass a restrictive filter: a place without
/// a price is not offered as "sem gasto", nor one without duration as "até 1 hora".
nonisolated struct DateFilters: Equatable, Sendable {
    var sources: Set<DateCandidate.Kind> = [.catalog]
    var location: LocationFilter = .any
    var cost: CostFilter = .any
    var duration: DurationFilter = .any
    /// Only what works over a call, apart.
    var remoteOnly = false

    var isDefault: Bool { self == DateFilters(sources: sources) }

    func matches(_ candidate: DateCandidate) -> Bool {
        guard sources.contains(candidate.kind) else { return false }
        switch location {
        case .any: break
        case .home: guard candidate.location == .casa || candidate.location == .flexivel else { return false }
        case .out: guard candidate.location == .fora || candidate.location == .flexivel else { return false }
        }
        switch cost {
        case .any: break
        case .noExtraCost: guard candidate.cost == .semGastoAdicional else { return false }
        case .upToLow: guard candidate.cost == .semGastoAdicional || candidate.cost == .baixo else { return false }
        }
        if duration != .any {
            guard let minutes = candidate.durationMinutes, minutes <= duration.rawValue else { return false }
        }
        if remoteOnly {
            // Out of home means being together somewhere; never offered as "apart".
            guard candidate.remoteFriendly, candidate.location != .fora else { return false }
        }
        return true
    }
}

nonisolated enum DateDraw {
    /// Candidates passing `filters`, without repeats: by ID, then by title (a saved place and
    /// an idea with the same name count once; the first source wins).
    static func eligible(_ candidates: [DateCandidate], filters: DateFilters) -> [DateCandidate] {
        var seenIDs = Set<String>()
        var seenTitles = Set<String>()
        return candidates.filter { candidate in
            guard filters.matches(candidate) else { return false }
            let title = candidate.title.trimmed.lowercased()
            guard seenIDs.insert(candidate.id).inserted, seenTitles.insert(title).inserted else { return false }
            return true
        }
    }

    /// A random eligible candidate not shown yet in this session. Nil when all were shown
    /// (the screen says so and offers to start over) or none passes the filters.
    static func next<Generator: RandomNumberGenerator>(
        from eligible: [DateCandidate],
        excluding shown: Set<String>,
        using generator: inout Generator
    ) -> DateCandidate? {
        eligible.filter { !shown.contains($0.id) }.randomElement(using: &generator)
    }
}

/// Answer to a date invitation, stored on the plan and changed in place.
nonisolated enum DateInvitation: String, Sendable {
    case pending
    case accepted
    case declined
    case cancelled
}
