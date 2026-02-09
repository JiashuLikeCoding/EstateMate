//
//  LocationAddressService.swift
//  EstateMate
//

import Foundation
import CoreLocation

@MainActor
final class LocationAddressService: NSObject {
    enum LocationError: LocalizedError {
        case notAuthorized
        case noPlacemark

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "未获得定位权限。请在系统设置中允许本 App 使用定位。"
            case .noPlacemark:
                return "获取当前位置失败，请稍后重试。"
            }
        }
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var continuation: CheckedContinuation<String, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func fillCurrentAddress() async throws -> String {
        if let continuation {
            continuation.resume(throwing: CancellationError())
            self.continuation = nil
        }

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            throw LocationError.notAuthorized
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            break
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }

    private func formatPlacemark(_ p: CLPlacemark) -> String {
        // Prefer a readable one-line address for quick editing.
        // Example: 123 Main St, Toronto, ON
        let street = [p.subThoroughfare, p.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank }
            .joined(separator: " ")
            .nilIfBlank

        let parts: [String?] = [
            street,
            p.locality,
            p.administrativeArea
        ]

        let line = parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank }
            .joined(separator: ", ")

        return line.nilIfBlank ?? (p.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "")
    }
}

extension LocationAddressService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            continuation?.resume(throwing: LocationError.notAuthorized)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            continuation?.resume(throwing: LocationError.noPlacemark)
            continuation = nil
            return
        }

        Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(loc)
                guard let p = placemarks.first else {
                    continuation?.resume(throwing: LocationError.noPlacemark)
                    continuation = nil
                    return
                }
                let formatted = formatPlacemark(p)
                continuation?.resume(returning: formatted)
                continuation = nil
            } catch {
                continuation?.resume(throwing: error)
                continuation = nil
            }
        }
    }
}
