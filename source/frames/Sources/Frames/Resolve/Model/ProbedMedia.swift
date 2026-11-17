//
//  ProbedMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The probed facts of one media file. `frames` holds a video's frame timestamps and `duration` its length, both in
// media time: the file's presentation timeline, which its picture and its sound share. A time before the first frame
// shows the first frame. `size` is the picture's, nil for sound, and `hasAlpha` says whether the picture carries
// alpha. `sound` is the format of the file's first sound track, nil when it has none.
package struct ProbedMedia: Equatable, Sendable {
    // MARK: - Property
    package let kind: MediaKind
    package let duration: Double
    package let fps: Double?
    package let frames: [Double]
    package let size: Size?
    package let hasAlpha: Bool
    package let sound: ProbedSound?

    package var hasSound: Bool {
        sound != nil
    }

    // MARK: - Initializer
    package init(
        kind: MediaKind,
        duration: Double = 0,
        fps: Double? = nil,
        frames: [Double] = [],
        size: Size? = nil,
        hasAlpha: Bool = false,
        sound: ProbedSound? = nil
    ) {
        self.kind = kind
        self.duration = duration
        self.fps = fps
        self.frames = frames
        self.size = size
        self.hasAlpha = hasAlpha
        self.sound = sound
    }

    // MARK: - Public
    // MARK: - Private
}
