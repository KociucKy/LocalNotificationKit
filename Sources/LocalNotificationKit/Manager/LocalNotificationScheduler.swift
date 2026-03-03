import Foundation
import UserNotifications

// MARK: - LocalNotificationError

/// Errors that can be thrown by `LocalNotificationManager`.
public enum LocalNotificationError: Error, Sendable, Equatable {
    /// The user has not granted notification permissions.
    case notAuthorized
    /// The system rejected the notification request.
    case schedulingFailed(underlying: any Error & Sendable)
    /// A time-interval trigger set to repeat has an interval shorter than 60 seconds.
    case repeatIntervalTooShort

    public static func == (lhs: LocalNotificationError, rhs: LocalNotificationError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthorized, .notAuthorized):             return true
        case (.repeatIntervalTooShort, .repeatIntervalTooShort): return true
        case (.schedulingFailed, .schedulingFailed):       return true
        default:                                           return false
        }
    }
}

// MARK: - LocalNotificationScheduler

/// Internal helper that owns all `UNUserNotificationCenter` interactions.
///
/// `nonisolated` functions are safe to call from any context; they bridge
/// callback-based `UNUserNotificationCenter` APIs into `async/await` using
/// `withCheckedContinuation` / `withCheckedThrowingContinuation`.
///
/// Marked `@unchecked Sendable` because `UNUserNotificationCenter` does not
/// conform to `Sendable`. The center is stored as a `let` constant and is only
/// accessed through its own thread-safe async API, so this is safe in practice.
struct LocalNotificationScheduler: @unchecked Sendable {

    // MARK: - Dependencies

    /// A pre-resolved center, or `nil` to use `UNUserNotificationCenter.current()` lazily.
    ///
    /// The lazy path (`nil`) defers calling `.current()` until the first actual
    /// interaction with the notification system. This avoids crashing in environments
    /// that don't have an app bundle (e.g. the SPM test runner on macOS).
    private let _center: UNUserNotificationCenter?

    private var center: UNUserNotificationCenter {
        _center ?? .current()
    }

    /// Creates a scheduler that uses `UNUserNotificationCenter.current()` on demand.
    init() {
        self._center = nil
    }

    /// Creates a scheduler backed by the provided center (useful for testing).
    init(center: UNUserNotificationCenter) {
        self._center = center
    }

    // MARK: - Authorization

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    func schedule(_ notification: LocalNotification) async throws {
        // Validate repeating time-interval triggers (system requires >= 60 s).
        if case .timeInterval(let interval, let repeats) = notification.trigger,
           repeats, interval < 60 {
            throw LocalNotificationError.repeatIntervalTooShort
        }

        let request = UNNotificationRequest.make(from: notification)
        do {
            try await center.add(request)
        } catch {
            throw LocalNotificationError.schedulingFailed(underlying: WrappedError(error))
        }
    }

    // MARK: - Fetching

    func pendingNotifications() async -> [LocalNotification] {
        await center.pendingNotificationRequests()
            .compactMap(\.localNotification)
    }

    func deliveredNotifications() async -> [LocalNotification] {
        await center.deliveredNotifications()
            .compactMap { $0.request.localNotification }
    }

    func pendingIDs() async -> Set<String> {
        let requests = await center.pendingNotificationRequests()
        return Set(requests.map(\.identifier))
    }

    func deliveredIDs() async -> Set<String> {
        let notifications = await center.deliveredNotifications()
        return Set(notifications.map(\.request.identifier))
    }

    // MARK: - Cancellation

    func cancel(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

// MARK: - WrappedError

/// Boxes a non-`Sendable` error so it can cross concurrency boundaries.
/// Used only as a last-resort fallback when the system throws a non-Sendable error type.
private struct WrappedError: Error, Sendable {
    let message: String
    init(_ error: any Error) { self.message = error.localizedDescription }
}
