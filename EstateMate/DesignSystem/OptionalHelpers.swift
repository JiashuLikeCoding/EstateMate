import Foundation
import UIKit

extension String {
    /// Returns nil if the string is empty after trimming spaces/newlines.
    /// Useful for fields where leading/trailing whitespace should be ignored.
    var nilIfBlank: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Returns nil only if the string is exactly empty (does NOT trim).
    /// Useful when we need to preserve user-entered spaces.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
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
