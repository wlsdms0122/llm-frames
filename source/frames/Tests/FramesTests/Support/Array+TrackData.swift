//
//  Array+TrackData.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

@testable import Frames

// Frames a fake tracker gives, written as the track data of a clip's `track` (FRAMES-12 Track data): `time` names the
// track's frame.
extension Array where Element == TrackedFrame {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func trackData(time: Double) -> String {
        let frames = map { frame in
            let corners = frame.quad.corners.map { corner in "[\(corner.x), \(corner.y)]" }
            return #"{ "time": \#(frame.time), "quad": [\#(corners.joined(separator: ", "))] }"#
        }

        return #"{ "time": \#(time), "frames": [\#(frames.joined(separator: ", "))] }"#
    }

    // MARK: - Private
}
