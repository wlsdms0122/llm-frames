//
//  ResolvedMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Media with what time knows of it. `reference` is the media as the document wrote it (`shorts/leak.mov`), the same on
// every machine, and nil for media written in place. `file` is the file or directory it was found at, which a role
// opens, and nil for a document or a template instance, whose plan is `nested`.
// `frames` is the first and last media time a picture exists at, nil for a still, which simply goes on, and for sound.
// `fps` is the nominal frame rate, when the media has one. `size` is the picture's, nil for sound and for a document,
// whose size is its own, and `frameTimes` holds the media time of each frame of a video or image sequence, which the
// resolved document pins. `frameFiles` holds the file of each frame of an image sequence, in frame order. `picture`
// is an image or layout document's, which draws its picture. `hasSound` says whether it plays sound: a file with a
// sound track, or a nested sequence that holds one.
struct ResolvedMedia: Equatable, Sendable {
    // MARK: - Property
    let kind: MediaKind
    let reference: String?
    let file: String?
    let duration: Double
    let fps: Double?
    let frames: ClosedRange<Double>?
    let nested: TimePlan?
    let size: Size?
    let frameTimes: [Double]
    let frameFiles: [String]
    let picture: NestedPicture?
    let hasSound: Bool

    // MARK: - Initializer
    init(
        kind: MediaKind,
        reference: String?,
        file: String?,
        duration: Double,
        fps: Double? = nil,
        frames: ClosedRange<Double>? = nil,
        nested: TimePlan? = nil,
        size: Size? = nil,
        frameTimes: [Double] = [],
        frameFiles: [String] = [],
        picture: NestedPicture? = nil,
        hasSound: Bool = false
    ) {
        self.kind = kind
        self.reference = reference
        self.file = file
        self.duration = duration
        self.fps = fps
        self.frames = frames
        self.nested = nested
        self.size = size
        self.frameTimes = frameTimes
        self.frameFiles = frameFiles
        self.picture = picture
        self.hasSound = hasSound
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

    func clamped(_ time: Double) -> Double {
        guard let frames else { return time }

        return min(max(time, frames.lowerBound), frames.upperBound)
    }

    // MARK: - Private
}
