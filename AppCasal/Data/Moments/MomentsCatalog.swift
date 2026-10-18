//
//  MomentsCatalog.swift
//  AppCasal
//

import Foundation

/// Editorial content of "Hoje, nós dois", shipped in the bundle (`Resources/Moments`):
/// 365 questions, 100 dates, 100 gestures and 60 game questions in pt-BR.
///
/// The JSON field names are kept as delivered; the only transformations are the enums
/// below (same raw values). IDs are stable: a new catalog version adds IDs and never
/// reuses old ones, and couple records keep snapshots of the text they used.
nonisolated struct MomentsCatalog: Sendable {
    static let supportedSchemaVersion = 1

    let questions: [CatalogQuestion]
    let dates: [CatalogDate]
    let gestures: [CatalogGesture]
    let gameQuestions: [CatalogGameQuestion]
    /// `catalogVersion` of each file, kept in the records created from it.
    let questionsVersion: String
    let datesVersion: String
    let gesturesVersion: String
    let gameVersion: String

    enum CatalogError: LocalizedError, Equatable {
        case missingFile(String)
        case unreadable(String, String)
        case unsupportedSchema(String, Int)
        case empty(String)
        case duplicateID(String)
        case invalidItem(String)

        var errorDescription: String? {
            String(localized: "O conteúdo de Hoje, nós dois não pôde ser carregado.")
        }

        /// For logs and tests; never shown to the couple.
        var detail: String {
            switch self {
            case .missingFile(let file): "missing \(file)"
            case .unreadable(let file, let reason): "\(file): \(reason)"
            case .unsupportedSchema(let file, let version): "\(file): schemaVersion \(version)"
            case .empty(let file): "\(file): no items"
            case .duplicateID(let id): "duplicate id \(id)"
            case .invalidItem(let id): "invalid item \(id)"
            }
        }
    }

    /// Reads and validates the four files. Throws on any structural problem instead of
    /// showing partial content.
    static func load(from bundle: Bundle = .main) throws -> MomentsCatalog {
        let questions = try decode(QuestionsFile.self, named: "perguntas", from: bundle)
        let dates = try decode(DatesFile.self, named: "dates", from: bundle)
        let gestures = try decode(GesturesFile.self, named: "gestos", from: bundle)
        let game = try decode(GameFile.self, named: "jogo", from: bundle)
        let catalog = MomentsCatalog(
            questions: questions.questions,
            dates: dates.dates,
            gestures: gestures.gestures,
            gameQuestions: game.questions,
            questionsVersion: questions.catalogVersion,
            datesVersion: dates.catalogVersion,
            gesturesVersion: gestures.catalogVersion,
            gameVersion: game.catalogVersion
        )
        try catalog.validate()
        return catalog
    }

    func validate() throws {
        for (file, count) in [("perguntas", questions.count), ("dates", dates.count), ("gestos", gestures.count), ("jogo", gameQuestions.count)]
        where count == 0 {
            throw CatalogError.empty(file)
        }
        var ids = Set<String>()
        let allIDs = questions.map(\.id) + dates.map(\.id) + gestures.map(\.id) + gameQuestions.map(\.id)
        for id in allIDs {
            guard ids.insert(id).inserted else { throw CatalogError.duplicateID(id) }
        }
        for question in questions where question.text.trimmed.isEmpty {
            throw CatalogError.invalidItem(question.id)
        }
        for date in dates where date.title.trimmed.isEmpty || date.description.trimmed.isEmpty || date.durationMinutes <= 0 {
            throw CatalogError.invalidItem(date.id)
        }
        for gesture in gestures where gesture.text.trimmed.isEmpty || gesture.durationMinutes <= 0 {
            throw CatalogError.invalidItem(gesture.id)
        }
        for question in gameQuestions {
            let optionIDs = Set(question.options.map(\.id))
            let optionTexts = Set(question.options.map { $0.text.trimmed.lowercased() })
            guard question.options.count == 4, optionIDs.count == 4, optionTexts.count == 4, !question.text.trimmed.isEmpty else {
                throw CatalogError.invalidItem(question.id)
            }
        }
    }

    func question(withID id: String) -> CatalogQuestion? { questions.first { $0.id == id } }
    func date(withID id: String) -> CatalogDate? { dates.first { $0.id == id } }
    func gesture(withID id: String) -> CatalogGesture? { gestures.first { $0.id == id } }

    private static func decode<File: CatalogFile>(_ type: File.Type, named name: String, from bundle: Bundle) throws -> File {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CatalogError.missingFile(name)
        }
        let file: File
        do {
            file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        } catch {
            throw CatalogError.unreadable(name, String(describing: error))
        }
        guard file.schemaVersion == supportedSchemaVersion else {
            throw CatalogError.unsupportedSchema(name, file.schemaVersion)
        }
        return file
    }
}

// MARK: - Items

nonisolated enum QuestionCategory: String, Codable, CaseIterable, Sendable {
    case humor
    case lembrancas
    case preferencias
    case carinho
    case futuro

    var title: String {
        switch self {
        case .humor: String(localized: "Humor")
        case .lembrancas: String(localized: "Lembranças")
        case .preferencias: String(localized: "Preferências")
        case .carinho: String(localized: "Carinho")
        case .futuro: String(localized: "Futuro")
        }
    }

    var systemImage: String {
        switch self {
        case .humor: "face.smiling"
        case .lembrancas: "clock.arrow.circlepath"
        case .preferencias: "slider.horizontal.3"
        case .carinho: "heart"
        case .futuro: "sparkles"
        }
    }
}

nonisolated struct CatalogQuestion: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let category: QuestionCategory
    let intensity: String
    let text: String
}

/// Where a date happens. `flexivel` fits both at home and out.
nonisolated enum DateLocation: String, Codable, CaseIterable, Sendable {
    case casa
    case fora
    case flexivel

    var title: String {
        switch self {
        case .casa: String(localized: "Em casa")
        case .fora: String(localized: "Fora de casa")
        case .flexivel: String(localized: "Em casa ou fora")
        }
    }
}

/// Cost guidance, never a price. `semGastoAdicional` uses what the couple already has
/// (travel or optional consumption may still cost); `variavel` and `aConfirmar` are
/// not a low budget.
nonisolated enum DateCost: String, Codable, CaseIterable, Sendable {
    case semGastoAdicional = "sem_gasto_adicional"
    case baixo
    case variavel
    /// Own ideas and saved places without an estimate.
    case aConfirmar = "a_confirmar"

    var title: String {
        switch self {
        case .semGastoAdicional: String(localized: "Sem gasto adicional")
        case .baixo: String(localized: "Custo baixo")
        case .variavel: String(localized: "Custo variável")
        case .aConfirmar: String(localized: "Custo a confirmar")
        }
    }
}

nonisolated struct CatalogDate: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let editorialGroup: String
    let title: String
    let description: String
    let location: DateLocation
    let costTier: DateCost
    /// Estimate.
    let durationMinutes: Int
    let materials: [String]
    let remoteFriendly: Bool
    let costNote: String
    let intensity: String
}

nonisolated struct CatalogGesture: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let text: String
    let durationMinutes: Int
    let remoteFriendly: Bool
    let intensity: String
}

nonisolated struct CatalogGameOption: Codable, Sendable, Identifiable, Hashable {
    /// Unique within its question only ("option-1"…); compared together with the question ID.
    let id: String
    let text: String
}

nonisolated struct CatalogGameQuestion: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let text: String
    let options: [CatalogGameOption]
    let intensity: String
}

// MARK: - Files

private nonisolated protocol CatalogFile: Decodable {
    var schemaVersion: Int { get }
    var catalogVersion: String { get }
}

private nonisolated struct QuestionsFile: CatalogFile {
    let schemaVersion: Int
    let catalogVersion: String
    let questions: [CatalogQuestion]
}

private nonisolated struct DatesFile: CatalogFile {
    let schemaVersion: Int
    let catalogVersion: String
    let dates: [CatalogDate]
}

private nonisolated struct GesturesFile: CatalogFile {
    let schemaVersion: Int
    let catalogVersion: String
    let gestures: [CatalogGesture]
}

private nonisolated struct GameFile: CatalogFile {
    let schemaVersion: Int
    let catalogVersion: String
    let questions: [CatalogGameQuestion]
}

nonisolated extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
