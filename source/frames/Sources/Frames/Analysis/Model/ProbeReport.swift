//
//  ProbeReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `probe` prints about a medium: its kind (`image`, `video`, `audio` or `imageSequence`), its picture's size,
// its duration and nominal frame rate, whether its picture carries alpha, and its first sound track's format. A value
// the medium does not have is nil: the size of sound, the duration and rate of an image, and the duration and rate of
// an image sequence, which the document's `fps` gives.
package struct ProbeReport: Equatable, Sendable {
    // MARK: - Property
    package let kind: String
    package let size: Size?
    package let duration: Double?
    package let fps: Double?
    package let hasAlpha: Bool
    package let sound: ProbedSound?

    // MARK: - Initializer
    init(
        kind: String,
        size: Size?,
        duration: Double?,
        fps: Double?,
        hasAlpha: Bool,
        sound: ProbedSound?
    ) {
        self.kind = kind
        self.size = size
        self.duration = duration
        self.fps = fps
        self.hasAlpha = hasAlpha
        self.sound = sound
    }

    init(_ probed: ProbedMedia) {
        self.init(
            kind: probed.kind.rawValue,
            size: probed.size,
            duration: probed.kind == .image ? nil : probed.duration,
            fps: probed.fps,
            hasAlpha: probed.hasAlpha,
            sound: probed.sound
        )
    }

    init(_ sequence: ProbedImageSequence) {
        self.init(
            kind: "imageSequence",
            size: sequence.size,
            duration: nil,
            fps: nil,
            hasAlpha: sequence.hasAlpha,
            sound: nil
        )
    }

    // MARK: - Public
    // MARK: - Private
}
