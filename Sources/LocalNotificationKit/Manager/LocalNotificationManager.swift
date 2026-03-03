import Foundation
import UserNotifications

/// The production implementation of `LocalNotificationManaging`.
///
/// All methods are isolated to `@MainActor` so they can be called directly
/// from SwiftUI views and UIKit view controllers without extra `await` hops.
///
/// ## Usage
/// ```swift
/// // Request permission once (e.g. on first launch)
/// let granted = try await LocalNotificationManager.shared.requestAuthorization()
///
/// // Schedule a notification
/// let notification = LocalNotification(
///     title: "Reminder",
///     body: "Don't forget to check in!",
///     trigger: .timeInterval(60 * 60, repeats: false)
/// )
/// try await LocalNotificationManager.shared.schedule(notification)
/// ```
@MainActor
public final class LocalNotificationManager: LocalNotificationManaging {

    // MARK: - Singleton

    /// The shared, app-wide notification manager.
    public static let shared = LocalNotificationManager()

    // MARK: - Private state

    private let scheduler: LocalNotificationScheduler

    // MARK: - Init

    /// Creates a manager backed by the given scheduler.
    ///
    /// Call `LocalNotificationManager()` for production use.
    /// Pass an explicit `center` only in unit tests that require a real app bundle.
    public init(center: UNUserNotificationCenter? = nil) {
        if let center {
            self.scheduler = LocalNotificationScheduler(center: center)
        } else {
            self.scheduler = LocalNotificationScheduler()
        }
    }

    // MARK: - Authorization

    public func requestAuthorization(
        options: UNAuthorizationOptions = [.alert, .sound, .badge]
    ) async throws -> Bool {
        try await scheduler.requestAuthorization(options: options)
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await scheduler.authorizationStatus()
    }

    // MARK: - Scheduling

    public func schedule(_ notification: LocalNotification) async throws {
        try await scheduler.schedule(notification)
    }

    public func scheduleAll(_ notifications: [LocalNotification]) async throws {
        for notification in notifications {
            try await scheduler.schedule(notification)
        }
    }

    // MARK: - Fetching

    public func pendingNotifications() async -> [LocalNotification] {
        await scheduler.pendingNotifications()
    }

    public func deliveredNotifications() async -> [LocalNotification] {
        await scheduler.deliveredNotifications()
    }

    public func status(for id: String) async -> NotificationStatus {
        let pendingIDs = await scheduler.pendingIDs()
        if pendingIDs.contains(id) { return .pending }

        let deliveredIDs = await scheduler.deliveredIDs()
        if deliveredIDs.contains(id) { return .delivered }

        return .cancelled
    }

    // MARK: - Cancellation

    public func cancel(id: String) async {
        scheduler.cancel(ids: [id])
    }

    public func cancel(ids: [String]) async {
        scheduler.cancel(ids: ids)
    }

    public func cancelAll() async {
        scheduler.cancelAll()
    }
}
