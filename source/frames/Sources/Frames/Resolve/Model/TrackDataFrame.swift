//
//  TrackDataFrame.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// One frame of track data as written (FRAMES-12): a media time of the tracked media, and the target's quad on the frame
// it names in media pixels. The key table has checked that a frame holds a number and four points of two numbers.
struct TrackDataFrame: Equatable, Sendable {
    // MARK: - Property
    let time: Double
    let quad: Quad

    // MARK: - Initializer
    init(
        time: Double,
        quad: Quad
    ) {
        self.time = time
        self.quad = quad
    }

    init?(value: JSONValue) {
        guard
            let object = value.objectValue,
            let time = object["time"]?.numberValue,
            let points = object["quad"]?.arrayValue?.compactMap(Self.point(of:)),
            points.count == 4
        else {
            return nil
        }

        self.init(
            time: time,
            quad: Quad(topLeft: points[0], topRight: points[1], bottomRight: points[2], bottomLeft: points[3])
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static func point(of value: JSONValue) -> Point? {
        guard let numbers = value.arrayValue?.compactMap(\.numberValue), numbers.count == 2 else { return nil }

        return Point(x: numbers[0], y: numbers[1])
    }
}
