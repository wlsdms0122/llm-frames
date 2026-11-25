//
//  MediaFile+ImageSequence.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// An image sequence in `directory` read at `fps` frames a second, as its media form reads it (FRAMES-3): its media
// seconds are frame index / fps, and its colour facts are its first frame's. Resolve and the commands that read an
// image sequence take it from here.
extension MediaFile {
    // MARK: - Property
    // Its length, its frame count / fps, so its last frame starts one frame before its end. Zero for media that is no
    // image sequence.
    var imageSequenceDuration: Double {
        guard let fps else { return 0 }

        return Double(frameFiles.count) / fps
    }

    // MARK: - Initializer
    init(
        imageSequence probed: ProbedImageSequence,
        in directory: String,
        fps: Double
    ) {
        self.init(
            path: directory,
            fps: fps,
            size: probed.size,
            frameTimes: probed.files.indices.map { Double($0) / fps },
            frameFiles: probed.files,
            colorReading: probed.colorSpace?.reading
        )
    }

    // MARK: - Public
    // MARK: - Private
}
