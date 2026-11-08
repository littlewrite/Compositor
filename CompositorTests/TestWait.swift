import Foundation

/// Waiting for something AppKit, the renderer or the file system finishes on its own: polled every 20 ms until it has,
/// or until the time a test gives it runs out. A test says what it waits for rather than how long to sleep.
@MainActor enum TestWait {
    static func until(_ seconds: Double = 5, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition() {
            guard ContinuousClock.now < deadline else { return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
