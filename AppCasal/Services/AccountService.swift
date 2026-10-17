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

    private let container: CKContainer

    init(container: CKContainer) {
        self.container = container
    }

    func refresh() async {
        do {
            switch try await container.accountStatus() {
            case .available:
                userRecordName = try await container.userRecordID().recordName
                status = .available
            case .noAccount:
                userRecordName = nil
                status = .noAccount
            case .restricted:
                userRecordName = nil
                status = .restricted
            case .temporarilyUnavailable:
                status = .temporarilyUnavailable
            case .couldNotDetermine:
                status = .couldNotDetermine
            @unknown default:
                status = .couldNotDetermine
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Refreshes whenever the system reports an iCloud account change. Runs until cancelled.
    func observeAccountChanges() async {
        for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
            await refresh()
        }
    }
}
