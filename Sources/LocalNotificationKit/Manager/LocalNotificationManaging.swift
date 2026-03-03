import Foundation
import UserNotifications

/// The public interface for scheduling, fetching, and cancelling local notifications.
///
/// Conform to this protocol in your own types (e.g. mocks for testing) and use
/// `LocalNotificationManager` as the production implementation.
///
/// All methods are isolated to `@MainActor` so they can be called directly from
/// SwiftUI views and `UIViewController`s without additional actor hopping.
@MainActor
public protocol LocalNotificationManaging: AnyObject, Sendable {

    // MARK: - Authorization

    /// Requests authorisation to display alerts, play sounds, and update the app badge.
    /// - Parameter options: The notification options to request. Defaults to `[.alert, .sound, .badge]`.
    /// - Returns: `true` if the user granted authorisation.
    /// - Throws: Any error returned by `UNUserNotificationCenter`.
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    /// Returns the current notification authorisation status without prompting the user.
    func authorizationStatus() async -> UNAuthorizationStatus

    // MARK: - Scheduling

    /// Schedules a single local notification.
    /// - Throws: `LocalNotificationError` or a system error if scheduling fails.
    func schedule(_ notification: LocalNotification) async throws

    /// Schedules multiple local notifications.
    /// Scheduling stops at the first failure and rethrows the error.
    func scheduleAll(_ notifications: [LocalNotification]) async throws

    // MARK: - Fetching

    /// Returns all notifications currently waiting to be delivered.
    func pendingNotifications() async -> [LocalNotification]

    /// Returns all notifications that have already been delivered.
    func deliveredNotifications() async -> [LocalNotification]

    /// Returns the status of a notification with the given identifier.
    func status(for id: String) async -> NotificationStatus

    // MARK: - Cancellation

    /// Removes a pending or delivered notification with the given identifier.
    func cancel(id: String) async

    /// Removes a set of pending or delivered notifications.
    func cancel(ids: [String]) async

    /// Removes all pending and delivered notifications.
    func cancelAll() async
}
