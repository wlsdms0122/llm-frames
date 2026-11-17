//
//  FrameSpan.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The times a video or a sequence, its `kind`, has frames at: [0, end), measured to the microsecond.
struct FrameSpan: Equatable, Sendable {
    // MARK: - Property
    let end: Double
    let kind: String

    // MARK: - Initializer
    init(
        end: Double,
        kind: String
    ) {
        self.end = end
        self.kind = kind
    }

    // MARK: - Public
    // Refuses `time`, given with `option`, when the span has no frame then.
    func check(
        _ time: Double,
        option: String
    ) throws {
        guard time.timeTicks >= 0, time.timeTicks < end.timeTicks else {
            throw ExportError.timeOutside(option: option, time: time, end: end, kind: kind)
        }
    }

    // MARK: - Private
}
