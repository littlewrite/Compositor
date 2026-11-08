import Foundation

/// Waiting for something UIKit, the renderer or the file system finishes on its own: polled every 20 ms until it has,
/// or until the time a test gives it runs out. One copy, so a suite says what it waits for, not how to wait.
@MainActor enum TestWait {
    static func until(_ seconds: Double = 5, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition() {
            guard ContinuousClock.now < deadline else { return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
