//
//  TimeMap.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The straight line from a clip's clock to sequence time: clip time `in` sits at sequence time `origin`, and clip time
// runs `speed` times as fast. The line goes on outside the clip, which is where handles and early keyframes lie.
struct TimeMap: Equatable, Sendable {
    // MARK: - Property
    static let sequence = TimeMap(origin: 0, in: 0, speed: 1)

    let origin: Double
    let `in`: Double
    let speed: Double

    // MARK: - Initializer
    init(
        origin: Double,
        in: Double,
        speed: Double
    ) {
        self.origin = origin
        self.in = `in`
        self.speed = speed
    }

    // MARK: - Public
    func sequenceTime(ofClipTime time: Double) -> Double {
        origin + (time - `in`) / speed
    }

    func clipTime(atSequenceTime time: Double) -> Double {
        `in` + (time - origin) * speed
    }

    // MARK: - Private
}
