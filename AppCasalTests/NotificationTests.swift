//
//  NotificationTests.swift
//  AppCasalTests
//

import CloudKit
import CoreData
import Foundation
import Testing
import UIKit
@testable import AppCasal

struct NotificationTests {
    @Test func noteAlertSubscriptionIsScopedToNotesAndNamesThePartner() {
        let subscription = NoteAlerts.makeSubscription(partnerName: "Lucas")
        #expect(subscription.subscriptionID == NoteAlerts.subscriptionID)
        #expect(subscription.recordType == NoteAlerts.noteRecordType)
        #expect(subscription.notificationInfo?.title == String(localized: "Recadinho de \("Lucas")"))
        #expect(subscription.notificationInfo?.alertBody?.isEmpty == false)
        #expect(subscription.notificationInfo?.soundName == "default")
        #expect(!NoteAlerts.legacySubscriptionIDs.contains(NoteAlerts.subscriptionID))
    }

    @Test func noteAlertsWatchTheDatabaseWhereThePartnersNotesArrive() {
        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        #expect(NoteAlerts.database(for: .owner, in: container).databaseScope == .private)
        #expect(NoteAlerts.database(for: .participant, in: container).databaseScope == .shared)
    }

    @Test func noteAlertPreferenceDefaultsToOnAndPersists() throws {
        let suite = "NotificationTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let alerts = NoteAlerts(defaults: defaults)
        #expect(alerts.isEnabled)
        alerts.isEnabled = false
        #expect(NoteAlerts(defaults: defaults).isEnabled == false)
    }

    @Test func nonCloudKitPayloadIsNotANoteAlert() {
        #expect(!NoteAlerts.isNoteAlert(["aps": ["alert": "Oi"]]))
    }

    @Test func shareThumbnailIsSquareWithAndWithoutCouplePhoto() throws {
        let persistence = PersistenceController(mode: .inMemory)
        let space = try SpaceRepository(persistence: persistence).createSpace(ownerName: "Ana", userRecordName: "_owner")
        let logo = ShareThumbnail.image(for: space)
        #expect(logo.size.width == logo.size.height)

        let photo = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20)).image { _ in
            UIColor.red.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 40, height: 20))
        }
        space.coverPhotoData = photo.jpegData(compressionQuality: 0.9)
        let cover = ShareThumbnail.image(for: space)
        #expect(cover.size == logo.size)
        #expect(ShareThumbnail.data(for: space) != nil)
    }
}
