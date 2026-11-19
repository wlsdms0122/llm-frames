//
//  SplitEdit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A J or an L cut: the seconds a clip's sound starts before its picture (`before`) and ends after it (`after`).
struct SplitEdit: Equatable, Sendable {
    // MARK: - Property
    let before: Double
    let after: Double

    // MARK: - Initializer
    init(before: Double = 0, after: Double = 0) {
        self.before = before
        self.after = after
    }

    init(_ object: JSONObject) {
        self.init(before: object["before"]?.numberValue ?? 0, after: object["after"]?.numberValue ?? 0)
    }

    // MARK: - Public
    // `range` with its start `before` earlier and its end `after` later.
    func moved(_ range: TimeRange) -> TimeRange {
        TimeRange(start: range.start - before, end: range.end + after)
    }

    // MARK: - Private
}
