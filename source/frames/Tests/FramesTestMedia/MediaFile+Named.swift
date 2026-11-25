//
//  MediaFile+Named.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/26/26.
//

import Frames

// A media file of each kind as a test names it to a role: by its frames alone, as pinned media names it, so the decoder
// reads its frame rate, size and colour from the file. A size is given where the role reads it, as a tracker does.
extension MediaFile {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    package static func video(
        _ path: String,
        frameTimes: [Double],
        size: Size? = nil
    ) -> MediaFile {
        MediaFile(path: path, kind: .video(frameTimes: frameTimes, fps: nil, size: size, colorReading: nil))
    }

    package static func still(
        _ path: String,
        size: Size? = nil
    ) -> MediaFile {
        MediaFile(path: path, kind: .still(size: size, colorReading: nil))
    }

    // An image sequence in `directory` read at `fps` frames a second, whose frame i is at i / fps.
    package static func imageSequence(
        _ directory: String,
        frameFiles: [String],
        fps: Double
    ) -> MediaFile {
        MediaFile(
            path: directory,
            kind: .imageSequence(
                frameFiles: frameFiles,
                frameTimes: frameFiles.indices.map { Double($0) / fps },
                fps: fps,
                size: nil,
                colorReading: nil
            )
        )
    }

    package static func page(
        _ path: String,
        page: Int
    ) -> MediaFile {
        MediaFile(path: path, kind: .page(page, size: nil))
    }

    package static func sound(_ path: String) -> MediaFile {
        MediaFile(path: path, kind: .sound)
    }

    // MARK: - Private
}
