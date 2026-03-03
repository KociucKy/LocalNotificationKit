import Testing
import Foundation
import UserNotifications
@testable import LocalNotificationKit

// MARK: - LocalNotificationManager Integration Tests
//
// Tests that touch UNUserNotificationCenter require an app bundle context to work
// (the UNUserNotificationCenter.current() singleton asserts when called outside
// an app process). Those tests are wrapped with a runtime availability check and
// skipped gracefully when running under the SPM test runner.
//
// Pure-logic tests (validation, status for unknown ID) run unconditionally.

// MARK: - Pure-logic tests (no UNUserNotificationCenter access)

@Suite("LocalNotificationManager — validation")
@MainActor
struct LocalNotificationManagerValidationTests {

    @Test("Scheduling a repeating timeInterval < 60s throws repeatIntervalTooShort")
    func shortRepeatIntervalThrows() async throws {
        let notification = LocalNotification(
            id: "short-repeat-\(UUID().uuidString)",
            title: "Too Fast",
            body: "Body",
            trigger: .timeInterval(10, repeats: true)
        )

        // Drive the validation path directly through the scheduler.
        // The repeat-interval check fires before UNUserNotificationCenter.add(_:)
        // is called, so this test is safe to run without an app bundle.
        let scheduler = LocalNotificationScheduler()
        do {
            try await scheduler.schedule(notification)
            Issue.record("Expected repeatIntervalTooShort to be thrown")
        } catch LocalNotificationError.repeatIntervalTooShort {
            // Expected — pass
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - Integration tests (require app bundle / notification daemon)
//
// These tests are intentionally skipped when running under `swift test` because
// UNUserNotificationCenter.current() requires a real app bundle context.
// Run them from Xcode in a simulator or device target instead.

@Suite("LocalNotificationManager — integration", .serialized)
@MainActor
struct LocalNotificationManagerTests {

    // MARK: - Authorization

    @Test("authorizationStatus returns a valid UNAuthorizationStatus")
    func authorizationStatusIsValid() async {
        await runIntegration { manager in
            let status = await manager.authorizationStatus()
            var validStatuses: [UNAuthorizationStatus] = [
                .notDetermined, .denied, .authorized, .provisional
            ]
            #if !os(macOS)
            validStatuses.append(.ephemeral)
            #endif
            #expect(validStatuses.contains(status))
        }
    }

    // MARK: - Scheduling & Fetching

    @Test("schedule adds a notification to the pending list")
    func scheduleAddsToPending() async {
        await runIntegration { manager in
            let notification = LocalNotification(
                id: "test-schedule-\(UUID().uuidString)",
                title: "Test",
                body: "Body",
                trigger: .timeInterval(3600, repeats: false)
            )
            try await manager.schedule(notification)
            let pending = await manager.pendingNotifications()
            await manager.cancel(id: notification.id)
            #expect(pending.contains { $0.id == notification.id })
        }
    }

    @Test("scheduleAll schedules multiple notifications")
    func scheduleAllAddsMultiple() async {
        await runIntegration { manager in
            let ids = (0..<3).map { "multi-\($0)-\(UUID().uuidString)" }
            let notifications = ids.map { id in
                LocalNotification(
                    id: id,
                    title: "Notification \(id)",
                    body: "Body",
                    trigger: .timeInterval(3600, repeats: false)
                )
            }
            try await manager.scheduleAll(notifications)
            let pending = await manager.pendingNotifications()
            let pendingIDs = Set(pending.map(\.id))
            await manager.cancel(ids: ids)
            for id in ids {
                #expect(pendingIDs.contains(id))
            }
        }
    }

    @Test("status returns .pending for a scheduled notification")
    func statusIsPendingAfterSchedule() async {
        await runIntegration { manager in
            let id = "status-pending-\(UUID().uuidString)"
            let notification = LocalNotification(
                id: id,
                title: "Status Test",
                body: "Body",
                trigger: .timeInterval(3600, repeats: false)
            )
            try await manager.schedule(notification)
            let status = await manager.status(for: id)
            await manager.cancel(id: id)
            #expect(status == .pending)
        }
    }

    @Test("status returns .cancelled for a notification that was never scheduled")
    func statusIsCancelledForUnknownID() async {
        await runIntegration { manager in
            let status = await manager.status(for: "non-existent-\(UUID().uuidString)")
            #expect(status == .cancelled)
        }
    }

    // MARK: - Cancellation

    @Test("cancel removes the notification from the pending list")
    func cancelRemovesFromPending() async {
        await runIntegration { manager in
            let id = "cancel-test-\(UUID().uuidString)"
            let notification = LocalNotification(
                id: id,
                title: "Cancel Me",
                body: "Body",
                trigger: .timeInterval(3600, repeats: false)
            )
            try await manager.schedule(notification)
            await manager.cancel(id: id)
            let pending = await manager.pendingNotifications()
            #expect(!pending.contains { $0.id == id })
        }
    }

    @Test("cancelAll removes all pending notifications scheduled by this test")
    func cancelAllRemovesAll() async {
        await runIntegration { manager in
            let ids = (0..<3).map { "cancelAll-\($0)-\(UUID().uuidString)" }
            let notifications = ids.map { id in
                LocalNotification(
                    id: id,
                    title: "CancelAll \(id)",
                    body: "Body",
                    trigger: .timeInterval(3600, repeats: false)
                )
            }
            try await manager.scheduleAll(notifications)
            await manager.cancelAll()
            let pending = await manager.pendingNotifications()
            let pendingIDs = Set(pending.map(\.id))
            for id in ids {
                #expect(!pendingIDs.contains(id))
            }
        }
    }

    // MARK: - Helpers

    /// Creates a `LocalNotificationManager` only when running inside an app bundle.
    /// Uses `withKnownIssue` to report the skip cleanly without a test failure
    /// when running under `swift test` (which has no app bundle context).
    private func makeManager() -> LocalNotificationManager? {
        guard Bundle.main.bundleIdentifier != nil else {
            return nil
        }
        return LocalNotificationManager()
    }

    /// Wraps an integration test body so it is reported as a known issue when
    /// `UNUserNotificationCenter` is unavailable (no app bundle context).
    private func runIntegration(_ body: (LocalNotificationManager) async throws -> Void) async {
        if let manager = makeManager() {
            do {
                try await body(manager)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        } else {
            withKnownIssue("UNUserNotificationCenter requires an app bundle. Run from Xcode.") {
                Issue.record("Integration test skipped outside app bundle context.")
            }
        }
    }
}
