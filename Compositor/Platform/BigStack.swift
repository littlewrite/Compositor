import Foundation

/// Runs pixel work off the main thread on a thread with room to spare. A concurrency thread's stack is small enough
/// that the filters' deepest paths (Core Graphics and the pixel code) overflow it there; the main thread's is not.
/// Work already on the main thread, or on this thread, runs where it is.
nonisolated enum BigStack {
    static func run<T>(_ body: @escaping () throws -> T) throws -> T {
        if Thread.isMainThread || Thread.current === Worker.shared.thread { return try body() }
        return try Worker.shared.run(body)
    }
}

/// One thread, kept for the app's life, with an 8 MB stack, taking one job at a time.
private final class Worker: @unchecked Sendable {
    static let shared = Worker()

    private let condition = NSCondition()
    private var jobs: [() -> Void] = []
    private(set) var thread: Thread?

    func run<T>(_ body: @escaping () throws -> T) throws -> T {
        var result: Result<T, Error>!
        let done = DispatchSemaphore(value: 0)
        let job = {
            result = Result { try body() }
            done.signal()
        }
        condition.lock()
        jobs.append(job)
        if thread == nil {
            let worker = Thread { [weak self] in self?.work() }
            worker.stackSize = 8 * 1024 * 1024
            worker.name = "com.compositor.pixels"
            thread = worker
            worker.start()
        }
        condition.signal()
        condition.unlock()
        done.wait()
        return try result.get()
    }

    private func work() {
        while true {
            condition.lock()
            while jobs.isEmpty { condition.wait() }
            let job = jobs.removeFirst()
            condition.unlock()
            job()
        }
    }
}
