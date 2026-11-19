//
//  TrackerProvider.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Follows a target through the frames of a video, read through the decoder.
package protocol TrackerProvider: Sendable {
    // Follows `target`, a quad on the frame of `file` shown at media time `time`, backwards and forwards over `range`
    // in media time, out to where it reports the target lost in each direction. Each frame gives the target's quad
    // there, its corners in the order of `target`'s. Frames come back in time order, the frame at `time` among them.
    // `target` lies inside the frame. Frames are read as analysis pictures, in `colorSpace` where one is given and as the
    // file's tags say otherwise.
    func track(
        _ target: Quad,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>,
        colorSpace: ColorSpace?
    ) throws -> [TrackedFrame]
}
