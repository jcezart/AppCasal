//
//  AccountService.swift
//  AppCasal
//

import CloudKit
import Observation

/// Tracks the iCloud account status and the current user's record name.
@Observable
final class AccountService {
    enum Status: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case couldNotDetermine
        case failed(String)
    }

    private(set) var status: Status = .checking
    /// Stable per-container identifier of the signed-in iCloud user.
    private(set) var userRecordName: String?

    private let container: CKContainer?
    private let defaults: UserDefaults
    /// The record name is an opaque, per-container identifier (not personal data).
    /// Keeping it lets the app open instantly and offline instead of waiting for
    /// the network round trip of `userRecordID()`.
    static let cachedUserRecordNameKey = "account.cachedUserRecordName"

    init(container: CKContainer, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
        if let cached = defaults.string(forKey: Self.cachedUserRecordNameKey) {
            userRecordName = cached
            status = .available
        }
    }

    /// Fixed local identity for the demo configuration. Never talks to iCloud.
    init(localUserRecordName: String) {
        container = nil
        defaults = .standard
        userRecordName = localUserRecordName
        status = .available
    }

    func refresh() async {
        guard let container else { return }
        do {
            switch try await container.accountStatus() {
            case .available:
                do {
                    let recordName = try await container.userRecordID().recordName
                    defaults.set(recordName, forKey: Self.cachedUserRecordNameKey)
                    userRecordName = recordName
                    status = .available
                } catch where userRecordName != nil {
                    // Offline or slow network: keep the identity known on this device.
                    status = .available
                }
            case .noAccount:
                clearIdentity()
                status = .noAccount
            case .restricted:
                clearIdentity()
                status = .restricted
            case .temporarilyUnavailable:
                keepLocalAccessOr(.temporarilyUnavailable)
            case .couldNotDetermine:
                keepLocalAccessOr(.couldNotDetermine)
            @unknown default:
                keepLocalAccessOr(.couldNotDetermine)
            }
        } catch {
            keepLocalAccessOr(.failed(error.localizedDescription))
        }
    }

    /// Transient problems never lock the user out of data already on this device.
    /// Only a missing or restricted account (handled above) does.
    private func keepLocalAccessOr(_ problem: Status) {
        status = userRecordName != nil ? .available : problem
    }

    private func clearIdentity() {
        userRecordName = nil
        defaults.removeObject(forKey: Self.cachedUserRecordNameKey)
    }

    /// Refreshes whenever the system reports an iCloud account change. Runs until cancelled.
    func observeAccountChanges() async {
        guard container != nil else { return }
        for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
            await refresh()
        }
    }
}
