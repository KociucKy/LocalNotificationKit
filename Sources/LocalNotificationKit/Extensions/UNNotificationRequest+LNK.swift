import Foundation
import UserNotifications

// MARK: - LocalNotification → UNNotificationRequest

public extension UNNotificationRequest {

    /// Builds a `UNNotificationRequest` from a `LocalNotification`.
    static func make(from notification: LocalNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.subtitle = notification.subtitle ?? ""
        content.body = notification.body
        content.categoryIdentifier = notification.categoryIdentifier

        if let badge = notification.badge {
            content.badge = NSNumber(value: badge)
        }

        if let sound = notification.sound.unNotificationSound {
            content.sound = sound
        }

        // Store user-supplied pairs, plus the sound name for round-trip fidelity.
        var info: [String: String] = notification.userInfo
        if case .named(let name) = notification.sound {
            info[LocalNotificationUserInfoKey.soundName] = name
        }
        content.userInfo = info

        return UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: notification.trigger.unNotificationTrigger
        )
    }

    // MARK: - UNNotificationRequest → LocalNotification

    /// Attempts to reconstruct a `LocalNotification` from a `UNNotificationRequest`.
    ///
    /// Returns `nil` when the trigger cannot be represented as a `NotificationTrigger`
    /// (e.g. a remote push notification trigger).
    var localNotification: LocalNotification? {
        guard let trigger = self.trigger?.notificationTrigger else { return nil }

        let badge: Int? = content.badge.flatMap { Int(truncating: $0) }

        let sound: NotificationSound
        if content.sound != nil {
            if let soundName = content.userInfo[LocalNotificationUserInfoKey.soundName] as? String {
                sound = .named(soundName)
            } else {
                sound = .default
            }
        } else {
            sound = .none
        }

        let userInfo = content.userInfo
            .compactMap { key, value -> (String, String)? in
                guard let k = key as? String, let v = value as? String else { return nil }
                guard k != LocalNotificationUserInfoKey.soundName else { return nil }
                return (k, v)
            }
            .reduce(into: [String: String]()) { $0[$1.0] = $1.1 }

        return LocalNotification(
            id: identifier,
            title: content.title,
            subtitle: content.subtitle.isEmpty ? nil : content.subtitle,
            body: content.body,
            userInfo: userInfo,
            trigger: trigger,
            badge: badge,
            sound: sound,
            categoryIdentifier: content.categoryIdentifier
        )
    }
}

// MARK: - UNNotificationTrigger → NotificationTrigger

extension UNNotificationTrigger {

    /// Converts a system `UNNotificationTrigger` back to our `NotificationTrigger` enum.
    var notificationTrigger: NotificationTrigger? {
        if let t = self as? UNTimeIntervalNotificationTrigger {
            return .timeInterval(t.timeInterval, repeats: t.repeats)
        }
        if let t = self as? UNCalendarNotificationTrigger {
            return .calendar(t.dateComponents, repeats: t.repeats)
        }
        #if os(iOS)
        if let t = self as? UNLocationNotificationTrigger {
            return .location(NotificationRegion(t.region), repeats: t.repeats)
        }
        #endif
        return nil
    }
}

// MARK: - Internal keys

/// Keys used internally to store metadata inside `UNNotificationContent.userInfo`.
enum LocalNotificationUserInfoKey {
    static let soundName = "__lnk_sound_name"
}
