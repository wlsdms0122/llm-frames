//
//  MemoryCorrection.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// The memory a run's process holds beyond what its budget counts in the process, as the budget adds it to its total:
// the largest of the readings of the last `window` (FRAMES-30 What it measures). A reading is taken as it comes and
// let go only once the window has passed it, so a reading taken after a grant is counted and before its memory is
// made, which is low by that grant, never lowers the correction under the readings before it. Not thread safe; the
// budget holds it under its lock.
struct MemoryCorrection: Sendable {
    // MARK: - Property
    // How long a reading counts.
    static let window = Duration.seconds(1)

    // What the budget adds to its total now, in bytes, 0 before the first reading.
    var bytes: Int {
        readings.first?.bytes ?? 0
    }

    // The largest reading so far, in bytes.
    private(set) var peak = 0

    // The readings that can still be the largest within the window: their times rising and their bytes falling.
    private var readings: [(time: ContinuousClock.Instant, bytes: Int)] = []

    // MARK: - Initializer
    // MARK: - Public
    // Records that the process held `bytes` past what the budget counted in it at `time`, a negative amount as 0.
    mutating func record(
        _ bytes: Int,
        at time: ContinuousClock.Instant
    ) {
        let bytes = max(0, bytes)
        readings.removeAll { $0.time + Self.window <= time }
        while let last = readings.last, last.bytes <= bytes {
            readings.removeLast()
        }
        readings.append((time, bytes))
        peak = max(peak, bytes)
    }

    // MARK: - Private
}
