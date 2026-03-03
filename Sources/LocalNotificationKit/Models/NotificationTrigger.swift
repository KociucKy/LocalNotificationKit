import Foundation
import UserNotifications
#if os(iOS)
import CoreLocation
#endif

/// A fully `Sendable` description of when a local notification should fire.
public enum NotificationTrigger: Sendable, Hashable {

    // MARK: - Cases

    /// Fire after the given time interval. Set `repeats` to `true` for recurring notifications.
    /// - Note: The interval must be at least 60 seconds when `repeats` is `true`.
    case timeInterval(TimeInterval, repeats: Bool)

    /// Fire at the date/time described by `DateComponents`. Set `repeats` to `true` for calendar-based recurrence.
    case calendar(DateComponents, repeats: Bool)

    #if os(iOS)
    // UNLocationNotificationTrigger is only available on iOS.
    // macOS, tvOS, and watchOS do not support CLLocationManager region monitoring
    // via UNLocationNotificationTrigger.

    /// Fire when the device enters or exits a geographic region (iOS only).
    case location(NotificationRegion, repeats: Bool)
    #endif

    // MARK: - Internal bridge

    /// Build the corresponding `UNNotificationTrigger`.
    var unNotificationTrigger: UNNotificationTrigger {
        switch self {
        case .timeInterval(let interval, let repeats):
            return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: repeats)
        case .calendar(let components, let repeats):
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        #if os(iOS)
        case .location(let region, let repeats):
            return UNLocationNotificationTrigger(region: region.clRegion, repeats: repeats)
        #endif
        }
    }
}

// MARK: - NotificationRegion

#if os(iOS)
/// A `Sendable` wrapper around `CLRegion` for use in location-based notification triggers.
///
/// `CLRegion` itself does not conform to `Sendable`, so this struct bridges the gap
/// by treating the underlying region as `@unchecked Sendable`. The stored region should
/// be treated as immutable after construction.
///
/// Location-based triggers are only available on iOS. `UNLocationNotificationTrigger`
/// is unavailable on macOS, tvOS, and watchOS.
public struct NotificationRegion: @unchecked Sendable, Hashable {

    /// The underlying Core Location region.
    public let clRegion: CLRegion

    public init(_ region: CLRegion) {
        self.clRegion = region
    }

    // MARK: Hashable

    public static func == (lhs: NotificationRegion, rhs: NotificationRegion) -> Bool {
        lhs.clRegion.identifier == rhs.clRegion.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(clRegion.identifier)
    }
}
#endif
