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
}
