import Foundation
import UserNotifications

/// The status of a local notification.
public enum NotificationStatus: String, Sendable, CaseIterable, Hashable, Codable {
    /// Scheduled but not yet delivered.
    case pending
    /// Delivered and visible in the notification centre.
    case delivered
    /// Explicitly cancelled / removed.
    case cancelled
}
