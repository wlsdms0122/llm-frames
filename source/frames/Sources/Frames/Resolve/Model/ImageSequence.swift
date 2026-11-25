//
//  ImageSequence.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// An image sequence read at `fps` frames a second, as its media form reads it (FRAMES-3): `file` is its directory with
// its frames, whose media seconds are frame index / fps and whose colour facts are its first frame's, and `duration`
// its frame count / fps, so its last frame starts one frame before its end. Resolve and the commands that read an
// image sequence take it from here.
struct ImageSequence: Equatable, Sendable {
    // MARK: - Property
    let file: MediaFile
    let duration: Double

    // MARK: - Initializer
    init(
        probed: ProbedImageSequence,
        directory: String,
        fps: Double
    ) {
        self.file = MediaFile(
            path: directory,
            kind: .imageSequence(
                frameFiles: probed.files,
                frameTimes: probed.files.indices.map { Double($0) / fps },
                fps: fps,
                size: probed.size,
                colorReading: probed.colorSpace?.reading
            )
        )
        self.duration = Double(probed.files.count) / fps
    }

    // MARK: - Public
    // MARK: - Private
}
