//
//  TimeRange.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `[start, end)`: every range and window holds its start and not its end, so a frame at an edit point belongs to
// the clip that starts there.
struct TimeRange: Equatable, Sendable {
    // MARK: - Property
    let start: Double
    let end: Double

    var length: Double {
        end - start
    }

    // MARK: - Initializer
    init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    // MARK: - Public
    func contains(_ time: Double) -> Bool {
        start <= time && time < end
    }

    func intersection(_ other: TimeRange) -> TimeRange? {
        let range = TimeRange(start: max(start, other.start), end: min(end, other.end))
        guard range.start < range.end else { return nil }

        return range
    }

    // MARK: - Private
}
