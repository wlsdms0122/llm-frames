//
//  TrackerProvider.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Follows a target through the frames of a video, read through the decoder.
package protocol TrackerProvider: Sendable {
    // Follows `target`, a rectangle on the frame of `file` shown at media time `time`, backwards and forwards over
    // `range` in media time, out to where it reports the target lost in each direction. Frames come back in time
    // order, the frame at `time` among them.
    func track(
        _ target: Rectangle,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>
    ) throws -> [TrackedFrame]
}
