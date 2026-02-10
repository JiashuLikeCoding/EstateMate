import Foundation
import UIKit

extension String {
    var nilIfBlank: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

enum DeviceIdentity {
    private static let key = "com.estatemate.device_id"

    static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let newValue = UUID().uuidString
        UserDefaults.standard.set(newValue, forKey: key)
        return newValue
    }

    static var deviceName: String {
        UIDevice.current.name
    }
}
