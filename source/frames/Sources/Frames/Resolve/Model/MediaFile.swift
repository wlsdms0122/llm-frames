//
//  MediaFile.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A media file or image sequence directory as it was found and probed. `path` is where it was found, which a role
// opens. `fps` is the nominal frame rate, when the media has one, and `size` is the picture's, nil for sound.
// `frameTimes` holds the media time of each frame of a video or image sequence, which the resolved document pins, and
// `frameFiles` the file of each frame of an image sequence, in frame order. `taggedColorSpace` is the space of the table
// its tags name (FRAMES-26 Media), `srgb` for an untagged picture and nil for sound or tags outside the table.
package struct MediaFile: Equatable, Sendable {
    // MARK: - Property
    package let path: String
    package let fps: Double?
    package let size: Size?
    package let frameTimes: [Double]
    package let frameFiles: [String]
    package let taggedColorSpace: ColorSpace?

    // MARK: - Initializer
    package init(
        path: String,
        fps: Double? = nil,
        size: Size? = nil,
        frameTimes: [Double] = [],
        frameFiles: [String] = [],
        taggedColorSpace: ColorSpace? = nil
    ) {
        self.path = path
        self.fps = fps
        self.size = size
        self.frameTimes = frameTimes
        self.frameFiles = frameFiles
        self.taggedColorSpace = taggedColorSpace
    }

    // MARK: - Public
    // The frame after the one shown at the media time, nil when that one is the last.
    func frameTime(after time: Double) -> Double? {
        frameTimes.first { $0.roundedTime > time.roundedTime }
    }

    // The frame shown at the media time: the last that starts at or before it, or the first before the media starts.
    func frameTime(at time: Double) -> Double? {
        frameTimes.last { $0.roundedTime <= time.roundedTime } ?? frameTimes.first
    }

    // The index of that frame, which a decoder reads. A still has the one frame 0.
    package func frameIndex(at time: Double) -> Int {
        frameTimes.lastIndex { $0.roundedTime <= time.roundedTime } ?? 0
    }

    // MARK: - Private
}
