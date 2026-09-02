import Foundation
import Observation

/// Wall-clock stopwatch.
///
/// Timers are suspended when the app is backgrounded or the phone locks, so a
/// counter that increments per tick silently loses time. This keeps only the
/// instant it started and how much was banked before the last pause, and derives
/// elapsed from `Date()`. Ticks exist to publish a new value, never to count — if
/// the app slept for four minutes, the first tick back reports four minutes.
@Observable
final class Stopwatch {
    /// Stored (not computed) so SwiftUI has something to observe each second.
    private(set) var elapsed: Int = 0

    private var banked: TimeInterval = 0
    private var startedAt: Date?

    var isRunning: Bool { startedAt != nil }

    var total: TimeInterval {
        banked + (startedAt.map { Date().timeIntervalSince($0) } ?? 0)
    }

    func start() {
        guard startedAt == nil else { return }
        startedAt = Date()
        sync()
    }

    func pause() {
        guard let s = startedAt else { return }
        banked += Date().timeIntervalSince(s)
        startedAt = nil
        sync()
    }

    func toggle() { isRunning ? pause() : start() }

    func reset() {
        banked = 0
        startedAt = nil
        sync()
    }

    /// Recompute from wall time. Call from the view's tick and on foreground.
    func sync() {
        let value = max(0, Int(total))
        if value != elapsed { elapsed = value }
    }
}
