//
//  MediaFile.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A media file or image sequence directory as it was found and probed, or as pinned media names it. `path` is where it
// was found, which a role opens, and `kind` what it is (`MediaFileKind`).
package struct MediaFile: Equatable, Sendable {
    // MARK: - Property
    package let path: String
    package let kind: MediaFileKind

    // The media time of each frame of a video or image sequence in frame order, none for a still, a page and a sound
    // file.
    package var frameTimes: [Double] {
        switch kind {
        case let .video(frameTimes, _, _, _), let .imageSequence(_, frameTimes, _, _, _):
            frameTimes

        case .still, .page, .sound:
            []
        }
    }

    // The nominal frame rate of a video or image sequence as the probe found it, nil for the other kinds and where
    // pinned media names the file.
    package var fps: Double? {
        switch kind {
        case let .video(_, fps, _, _), let .imageSequence(_, _, fps, _, _):
            fps

        case .still, .page, .sound:
            nil
        }
    }

    // The picture's size as the probe found it, nil for a sound file and where pinned media names the file.
    package var size: Size? {
        switch kind {
        case let .video(_, _, size, _),
             let .still(size, _),
             let .imageSequence(_, _, _, size, _),
             let .page(_, size):
            size

        case .sound:
            nil
        }
    }

    // How a decoder takes the pictures to working values as the probe found it, `srgb` for a page, whose untagged
    // colour it is, and nil for a sound file and where pinned media names a file of another kind.
    package var colorReading: ColorReading? {
        switch kind {
        case let .video(_, _, _, colorReading),
             let .still(_, colorReading),
             let .imageSequence(_, _, _, _, colorReading):
            colorReading

        case .page:
            .formulas(.srgb)

        case .sound:
            nil
        }
    }

    // The number of the page of a PDF the file names, counted from 1, nil for every other kind.
    package var page: Int? {
        guard case let .page(page, _) = kind else { return nil }

        return page
    }

    // The space of the table its tags name, `srgb` for an untagged picture, and nil for sound, for tags outside the
    // table and for a picture only the platform's colour management reads.
    package var taggedColorSpace: ColorSpace? {
        guard case let .formulas(space)? = colorReading else { return nil }

        return space
    }

    // MARK: - Initializer
    package init(
        path: String,
        kind: MediaFileKind
    ) {
        self.path = path
        self.kind = kind
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
