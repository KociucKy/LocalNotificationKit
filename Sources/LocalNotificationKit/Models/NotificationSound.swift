import Foundation
import UserNotifications

/// A `Sendable`, platform-safe replacement for `UNNotificationSound`.
public enum NotificationSound: Sendable, Hashable, Codable {
    /// The default system notification sound.
    case `default`
    /// A custom sound by file name (must be included in the app bundle).
    case named(String)
    /// No sound.
    case none

    // MARK: - Internal bridge

    var unNotificationSound: UNNotificationSound? {
        switch self {
        case .default:      return .default
        case .named(let n): return .init(named: .init(rawValue: n))
        case .none:         return nil
        }
    }
}
