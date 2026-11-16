//
//  MediaFile+ProbedMedia.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The file a role reads for a media file found at `path`, with the frame rate, size and frame times its probe gave.
extension MediaFile {
    // MARK: - Property
    // MARK: - Initializer
    init(
        path: String,
        probed: ProbedMedia
    ) {
        self.init(path: path, fps: probed.fps, size: probed.size, frameTimes: probed.frames)
    }

    // MARK: - Public
    // MARK: - Private
}
