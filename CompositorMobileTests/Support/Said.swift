import Foundation
@testable import Compositor

/// What a few threads at once have said, in the order they said it.
nonisolated final class Said<Event: Sendable>: Sendable {
    private let said = Mutex<[Event]>([])
    func add(_ event: Event) { said.withLock { $0.append(event) } }
    var events: [Event] { said.withLock { $0 } }
}
