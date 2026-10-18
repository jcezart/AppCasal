//
//  NetworkMonitor.swift
//  AppCasal
//

import Network
import Observation

/// Whether the device currently has a network path. Edits keep working offline;
/// this only drives the sync banner.
@Observable
final class NetworkMonitor {
    private(set) var isConnected = true

    /// Follows path changes until cancelled.
    func observe() async {
        for await path in NWPathMonitor() {
            isConnected = path.status == .satisfied
        }
    }
}
