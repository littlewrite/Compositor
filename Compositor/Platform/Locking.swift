import Foundation
import os

/// A value behind a lock, as `Synchronization`'s `Mutex` is: read and written from a few threads at once, as a
/// project's files are, with one holding it at a time. An unfair lock, the kind `Mutex` uses, so it's as quick.
final class Mutex<Value>: @unchecked Sendable {
    private var unfair = os_unfair_lock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        os_unfair_lock_lock(&unfair)
        defer { os_unfair_lock_unlock(&unfair) }
        return try body(&value)
    }
}

/// A count or flag a few threads share, as `Synchronization`'s `Atomic` is. The orderings it asks for only say how much
/// may be reordered around it; an unfair lock is stronger than all of them.
final class Atomic<Value: Sendable>: @unchecked Sendable {
    private var unfair = os_unfair_lock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func load(ordering: AtomicOrdering = .relaxed) -> Value {
        os_unfair_lock_lock(&unfair)
        defer { os_unfair_lock_unlock(&unfair) }
        return value
    }

    func store(_ newValue: Value, ordering: AtomicOrdering = .relaxed) {
        os_unfair_lock_lock(&unfair)
        defer { os_unfair_lock_unlock(&unfair) }
        value = newValue
    }

    @discardableResult
    func exchange(_ newValue: Value, ordering: AtomicOrdering = .acquiringAndReleasing) -> Value {
        os_unfair_lock_lock(&unfair)
        defer { os_unfair_lock_unlock(&unfair) }
        let old = value
        value = newValue
        return old
    }

    @discardableResult
    func add(_ amount: Value, ordering: AtomicOrdering = .relaxed) -> (oldValue: Value, newValue: Value)
    where Value: AdditiveArithmetic {
        os_unfair_lock_lock(&unfair)
        defer { os_unfair_lock_unlock(&unfair) }
        let old = value
        value = old + amount
        return (old, value)
    }
}

/// The orderings `Atomic` takes, as `Synchronization`'s are named: an unfair lock makes them all the same.
enum AtomicOrdering: Sendable {
    case relaxed
    case acquiringAndReleasing
}
