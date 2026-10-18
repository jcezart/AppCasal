//
//  MemoryTests.swift
//  AppCasalTests
//

import CoreData
import Foundation
import ImageIO
import Testing
import UIKit
@testable import AppCasal

struct MemoryTests {
    private let owner = "_owner"
    private let partner = "_partner"

    private static func sampleImageData(width: Int = 1200, height: Int = 800) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func makeSpace(_ persistence: PersistenceController) throws -> CoupleSpace {
        try SpaceRepository(persistence: persistence).createSpace(ownerName: "Ana", userRecordName: owner)
    }

    @Test func photoProcessingDownscalesAndMakesThumbnail() async throws {
        let processed = try await PhotoProcessing.process(Self.sampleImageData(width: 4000, height: 3000))
        #expect(max(processed.pixelWidth, processed.pixelHeight) == PhotoProcessing.maxPixelSize)
        #expect(processed.pixelWidth > processed.pixelHeight, "keeps aspect ratio")
        let thumbnail = try #require(CGImageSourceCreateWithData(processed.thumbnailData as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(thumbnail, 0, nil) as? [CFString: Any])
        let thumbWidth = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        #expect(thumbWidth <= PhotoProcessing.thumbnailPixelSize)
        #expect(processed.thumbnailData.count < processed.imageData.count)
    }

    @Test func photoProcessingRejectsGarbage() async {
        await #expect(throws: PhotoProcessing.ProcessingError.self) {
            try await PhotoProcessing.process(Data("not an image".utf8))
        }
    }

    @Test func createStoresFieldsAndPhotosInSpaceStore() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let repository = MemoryRepository(persistence: persistence)
        let photo = try PhotoProcessing.processSynchronously(Self.sampleImageData())
        let date = Date(timeIntervalSince1970: 1_790_000_000)

        let memory = try repository.create(
            MemoryDraft(title: "  Nosso fim de tarde ", details: "Pôr do sol", date: date, category: .beach),
            photos: [photo, photo],
            in: space,
            by: owner
        )

        #expect(memory.title == "Nosso fim de tarde")
        #expect(memory.details == "Pôr do sol")
        #expect(memory.date == date)
        #expect(memory.memoryCategory == .beach)
        #expect(memory.createdBy == owner)
        #expect(memory.objectID.persistentStore == persistence.privateStore)
        #expect(memory.visiblePhotos.map(\.sortIndex) == [0, 1])
        #expect(memory.visiblePhotos.allSatisfy { $0.objectID.persistentStore == persistence.privateStore })
    }

    @Test func emptyTitleIsRejected() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        #expect(throws: MemoryRepository.MemoryError.self) {
            try MemoryRepository(persistence: persistence).create(MemoryDraft(title: "   "), photos: [], in: space, by: owner)
        }
    }

    @Test func updateRemovesPhotosLogicallyAndAppendsNewOnes() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let repository = MemoryRepository(persistence: persistence)
        let photo = try PhotoProcessing.processSynchronously(Self.sampleImageData())
        let memory = try repository.create(MemoryDraft(title: "Viagem"), photos: [photo, photo], in: space, by: owner)
        let first = try #require(memory.visiblePhotos.first)

        var draft = MemoryDraft(title: "Viagem à praia")
        draft.category = .trip
        try repository.update(memory, with: draft, removing: [first.objectID], adding: [photo], by: partner)

        #expect(memory.title == "Viagem à praia")
        #expect(memory.memoryCategory == .trip)
        #expect(memory.modifiedBy == partner)
        #expect(memory.visiblePhotos.count == 2)
        #expect(memory.visiblePhotos.map(\.sortIndex) == [1, 2])
        #expect(first.deletedAt != nil && first.deletedBy == partner && !first.isDeleted, "removal is logical")
        #expect(memory.photos?.count == 3)
    }

    @Test func softDeleteAndRestore() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let repository = MemoryRepository(persistence: persistence)
        let memory = try repository.create(MemoryDraft(title: "Encontro"), photos: [], in: space, by: owner)

        try repository.softDelete(memory, by: partner)
        #expect(memory.deletedAt != nil && memory.deletedBy == partner && !memory.isDeleted)

        try repository.restore(memory, by: owner)
        #expect(memory.deletedAt == nil && memory.deletedBy == nil)
    }

    /// Closing and reopening the app: memories and photo bytes survive a new stack on the same files.
    @Test func memoriesWithPhotosSurviveReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = try PhotoProcessing.processSynchronously(Self.sampleImageData())

        do {
            let persistence = PersistenceController(mode: .local(directory: directory))
            let space = try makeSpace(persistence)
            let repository = MemoryRepository(persistence: persistence)
            let memory = try repository.create(MemoryDraft(title: "Primeira"), photos: [photo], in: space, by: owner)
            try repository.update(memory, with: MemoryDraft(title: "Primeira, editada"), by: owner)
            for store in persistence.container.persistentStoreCoordinator.persistentStores {
                try persistence.container.persistentStoreCoordinator.remove(store)
            }
        }

        let reopened = PersistenceController(mode: .local(directory: directory))
        let space = try #require(SpaceRepository(persistence: reopened).activeSpace())
        let memory = try #require(space.memories?.first)
        #expect(memory.title == "Primeira, editada")
        #expect(memory.visiblePhotos.first?.imageData == photo.imageData)
        #expect(memory.visiblePhotos.first?.thumbnailData == photo.thumbnailData)
    }

    @Test func timelineGroupsByMonthNewestFirst() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try makeSpace(persistence)
        let repository = MemoryRepository(persistence: persistence)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        func day(_ month: Int, _ day: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)))
        }
        let memories = try [(10, 12), (10, 5), (9, 30)].map { month, dayOfMonth in
            try repository.create(MemoryDraft(title: "M\(month)-\(dayOfMonth)", date: day(month, dayOfMonth)), photos: [], in: space, by: owner)
        }

        let sections = MonthSection.group(memories, calendar: calendar)
        #expect(sections.map(\.memories.count) == [2, 1])
        #expect(sections.allSatisfy { $0.title.first?.isUppercase == true })
    }
}
