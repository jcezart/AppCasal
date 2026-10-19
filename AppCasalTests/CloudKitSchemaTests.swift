//
//  CloudKitSchemaTests.swift
//  AppCasalTests
//

import CoreData
import Testing
@testable import AppCasal

/// The model must satisfy NSPersistentCloudKitContainer's documented constraints.
struct CloudKitSchemaTests {
    private let model = PersistenceController.model

    @Test func attributesAreOptionalOrDefaulted() {
        for entity in model.entities {
            for attribute in entity.attributesByName.values {
                #expect(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name ?? "").\(attribute.name)")
            }
        }
    }

    @Test func relationshipsAreOptionalUnorderedWithInverse() {
        for entity in model.entities {
            for relationship in entity.relationshipsByName.values {
                let name = "\(entity.name ?? "").\(relationship.name)"
                #expect(relationship.isOptional, "\(name) must be optional")
                #expect(!relationship.isOrdered, "\(name) must not be ordered")
                #expect(relationship.inverseRelationship != nil, "\(name) needs an inverse")
                #expect(relationship.deleteRule != .denyDeleteRule, "\(name) must not use Deny")
            }
        }
    }

    @Test func noUniquenessConstraints() {
        for entity in model.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name ?? "")")
        }
    }

    /// The alert subscriptions and the extension read mirrored records by name: the
    /// record types and fields must exist in the model (and so in the CloudKit schema).
    @Test func alertRecordTypesAndFieldsMatchTheModel() {
        let checks: [(recordType: String, keys: [String])] = [
            (NoteAlertContent.recordType, NoteAlertContent.desiredKeys),
            (AnswerAlertContent.recordType, AnswerAlertContent.desiredKeys),
            (GameAlertContent.recordType, GameAlertContent.desiredKeys),
        ]
        for check in checks {
            let entityName = String(check.recordType.dropFirst(3))
            let entity = model.entitiesByName[entityName]
            #expect(check.recordType.hasPrefix("CD_") && entity != nil, "\(check.recordType)")
            for key in check.keys {
                #expect(entity?.attributesByName[String(key.dropFirst(3))] != nil, "\(check.recordType).\(key)")
            }
        }
    }
}
