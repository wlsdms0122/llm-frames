//
//  EnvelopeCursor.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Reads an envelope at times that only go forward: straight lines between its points, and the value of the nearest
// end point outside them. Each read starts from the span the last one ended in, so reading a segment sample by sample
// walks its points once.
package struct EnvelopeCursor: Sendable {
    // MARK: - Property
    private let points: [EnvelopePoint]
    private var point = 0

    // MARK: - Initializer
    // `points` holds at least one point.
    package init(points: [EnvelopePoint]) {
        self.points = points
    }

    package init(value: MixValue) {
        switch value {
        case let .constant(number):
            self.init(points: [EnvelopePoint(time: 0, value: number)])

        case let .envelope(points):
            self.init(points: points)
        }
    }

    // MARK: - Public
    package mutating func value(at time: Double) -> Double {
        while point + 1 < points.count && points[point + 1].time <= time {
            point += 1
        }
        let from = points[point]
        guard point + 1 < points.count, time > from.time else { return from.value }
        let to = points[point + 1]
        let fraction = (time - from.time) / (to.time - from.time)

        return from.value + (to.value - from.value) * fraction
    }

    // MARK: - Private
}
