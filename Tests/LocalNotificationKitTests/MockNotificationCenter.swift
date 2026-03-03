import Foundation
import UserNotifications
@testable import LocalNotificationKit

// MARK: - MockUNUserNotificationCenter

/// An in-memory `UNUserNotificationCenter` substitute for unit testing.
///
/// Because `UNUserNotificationCenter` is a class we cannot subclass easily in tests,
/// `LocalNotificationScheduler` is initialised with a real `UNUserNotificationCenter`
/// in production. For tests we expose an internal initialiser that accepts
/// a `MockNotificationCenter` wrapped behind a thin protocol.
///
/// The mock stores scheduled requests in memory and simulates delivery/cancellation
/// without involving the OS notification daemon.
final class MockNotificationCenter: @unchecked Sendable {

    // MARK: - Stored state

    private(set) var pendingRequests: [UNNotificationRequest] = []
    private(set) var deliveredNotifications: [UNNotification] = []
    private(set) var requestedAuthOptions: UNAuthorizationOptions?

    var authorizationGranted = true
    var authorizationError: Error?
    var addError: Error?

    // MARK: - Helpers for tests

    /// Simulate delivery of a pending request (moves it to the delivered list).
    func deliver(id: String) {
        guard let request = pendingRequests.first(where: { $0.identifier == id }) else { return }
        pendingRequests.removeAll { $0.identifier == id }
        // UNNotification cannot be instantiated directly; store the request instead
        // and override `deliveredNotifications` with a parallel array of requests.
        _deliveredRequests.append(request)
    }

    private(set) var _deliveredRequests: [UNNotificationRequest] = []

    // MARK: - Center-like API (mirrors UNUserNotificationCenter)

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthOptions = options
        if let error = authorizationError { throw error }
        return authorizationGranted
    }

    func notificationSettings() async -> MockNotificationSettings {
        MockNotificationSettings(status: authorizationGranted ? .authorized : .denied)
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let error = addError { throw error }
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        pendingRequests.removeAll()
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        _deliveredRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllDeliveredNotifications() {
        _deliveredRequests.removeAll()
    }
}

// MARK: - MockNotificationSettings

struct MockNotificationSettings {
    let status: UNAuthorizationStatus
    var authorizationStatus: UNAuthorizationStatus { status }
}
