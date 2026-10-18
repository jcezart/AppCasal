//
//  LocationService.swift
//  AppCasal
//

import CoreLocation
import Observation

/// When-in-use location, only to show distances on the map. Permission is requested
/// when the map is first shown, never at launch.
@Observable
final class LocationService {
    private(set) var current: CLLocation?
    private(set) var isDenied = false
    @ObservationIgnored private let manager = CLLocationManager()

    /// Asks for permission if needed and takes one location fix.
    func updateLocation() async {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    isDenied = true
                    return
                }
                if let location = update.location {
                    current = location
                    isDenied = false
                    return
                }
            }
        } catch {
            // No fix: distances are simply not shown.
        }
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> Measurement<UnitLength>? {
        guard let current else { return nil }
        let meters = current.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        return Measurement(value: meters, unit: .meters)
    }
}
