//
//  PersistenceController.swift
//  AppCasal
//

import CloudKit
import CoreData

/// Owns the Core Data stack: one store mirrored to the private CloudKit database
/// and one mirrored to the shared database, both in the same container.
final class PersistenceController {
    enum Mode {
        /// Production stack with CloudKit mirroring.
        case cloudKit
        /// SQLite stores without CloudKit, for tests that need to reopen the store.
        case local(directory: URL)
        /// In-memory stores without CloudKit, for unit tests and previews.
        case inMemory
    }

    nonisolated static let cloudKitContainerIdentifier = "iCloud.jc.app.dev.casal"

    /// Loaded once: several models in one process make Core Data warn about
    /// ambiguous entity classes.
    static let model: NSManagedObjectModel = {
        guard let url = Bundle(for: PersistenceController.self).url(forResource: "AppCasal", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Core Data model AppCasal.momd not found in bundle")
        }
        return model
    }()

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    private(set) var loadError: Error?
    let mode: Mode

    var viewContext: NSManagedObjectContext { container.viewContext }

    var cloudKitContainer: CKContainer {
        CKContainer(identifier: Self.cloudKitContainerIdentifier)
    }

    init(mode: Mode) {
        self.mode = mode
        container = NSPersistentCloudKitContainer(name: "AppCasal", managedObjectModel: Self.model)

        let privateDescription = Self.storeDescription(named: "Private", scope: .private, mode: mode)
        let sharedDescription = Self.storeDescription(named: "Shared", scope: .shared, mode: mode)
        container.persistentStoreDescriptions = [privateDescription, sharedDescription]

        LaunchLog.mark("stores loading")
        var firstError: Error?
        container.loadPersistentStores { _, error in
            if let error, firstError == nil {
                firstError = error
            }
        }
        loadError = firstError
        LaunchLog.mark("stores loaded")

        let coordinator = container.persistentStoreCoordinator
        privateStore = privateDescription.url.flatMap { coordinator.persistentStore(for: $0) }
        sharedStore = sharedDescription.url.flatMap { coordinator.persistentStore(for: $0) }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.transactionAuthor = "app"
    }

    private static func storeDescription(
        named name: String,
        scope: CKDatabase.Scope,
        mode: Mode
    ) -> NSPersistentStoreDescription {
        let description: NSPersistentStoreDescription
        switch mode {
        case .cloudKit:
            let url = NSPersistentContainer.defaultDirectoryURL().appending(path: "\(name).sqlite")
            description = NSPersistentStoreDescription(url: url)
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)
            options.databaseScope = scope
            description.cloudKitContainerOptions = options
        case .local(let directory):
            description = NSPersistentStoreDescription(url: directory.appending(path: "\(name).sqlite"))
        case .inMemory:
            // Distinct paths keep the two in-memory stores apart.
            description = NSPersistentStoreDescription(url: URL(filePath: "/dev/null/\(name)"))
            description.type = NSInMemoryStoreType
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        return description
    }

    /// Whether `object` lives in the store mirrored to the shared database
    /// (that is, the current user is a participant, not the owner).
    func isInSharedStore(_ object: NSManagedObject) -> Bool {
        guard let sharedStore else { return false }
        return object.objectID.persistentStore == sharedStore
    }

    func save() throws {
        guard viewContext.hasChanges else { return }
        try viewContext.save()
    }

    #if DEBUG
    /// DEBUG, run once from Xcode with `-AppCasalInitializeCloudKitSchema YES` on a device
    /// signed in to iCloud: uploads every record type and field of the current model to
    /// the Development environment, so it can be deployed to Production in the CloudKit
    /// Console. Uses a throwaway private-only store in a temporary folder; the real stores
    /// and their data are not touched. CloudKit creates sample records and removes them.
    nonisolated static func initializeDevelopmentSchema() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "SchemaInit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // Its own copy of the model, off the main actor (Core Data may warn about the
        // second model in the process; harmless for this one-off tool).
        guard let url = Bundle(for: PersistenceController.self).url(forResource: "AppCasal", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else { throw CocoaError(.fileNoSuchFile) }
        let container = NSPersistentCloudKitContainer(name: "AppCasalSchema", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: directory.appending(path: "Schema.sqlite"))
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        try container.initializeCloudKitSchema(options: [])
    }
    #endif
}
