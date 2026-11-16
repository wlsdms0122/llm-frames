//
//  MediaFile.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A media file or image sequence directory as it was found and probed. `path` is where it was found, which a role
// opens. `fps` is the nominal frame rate, when the media has one, and `size` is the picture's, nil for sound.
// `frameTimes` holds the media time of each frame of a video or image sequence, which the resolved document pins, and
// `frameFiles` the file of each frame of an image sequence, in frame order.
struct MediaFile: Equatable, Sendable {
    // MARK: - Property
    let path: String
    let fps: Double?
    let size: Size?
    let frameTimes: [Double]
    let frameFiles: [String]

    // MARK: - Initializer
    init(
        path: String,
        fps: Double? = nil,
        size: Size? = nil,
        frameTimes: [Double] = [],
        frameFiles: [String] = []
    ) {
        self.path = path
        self.fps = fps
        self.size = size
        self.frameTimes = frameTimes
        self.frameFiles = frameFiles
    }

    // MARK: - Public
    // The frame after the one shown at the media time, nil when that one is the last.
    func frameTime(after time: Double) -> Double? {
        frameTimes.first { $0 > time }
    }

    // The frame shown at the media time: the last that starts at or before it, or the first before the media starts.
    func frameTime(at time: Double) -> Double? {
        frameTimes.last { $0 <= time } ?? frameTimes.first
    }

    // MARK: - Private
}
