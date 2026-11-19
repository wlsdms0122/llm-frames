//
//  MediaPictureCache.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Frames
import os

// Media pictures read through the decoder, kept for the renderer's lifetime: the last few frames of each file, as a
// sequence draws a file's frames in order and a transition shows two of them. A frame is kept for each reading of it.
final class MediaPictureCache: Sendable {
    // MARK: - Property
    private static let framesPerFile = 4

    private let decoder: any MediaDecoder
    private let pictures = OSAllocatedUnfairLock<[String: [(index: Int, reading: PictureReading, image: CGImage)]]>(
        uncheckedState: [:]
    )

    // MARK: - Initializer
    init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // The frame as working values, in its colour space and tone mapped to its target peak.
    func image(of frame: MediaFrame) throws -> CGImage {
        try image(of: frame, reading: .working(colorSpace: frame.colorSpace, targetPeak: frame.targetPeak))
    }

    // The frame as an analysis picture in its colour space, as a transition matte is read (FRAMES-26).
    func analysisImage(of frame: MediaFrame) throws -> CGImage {
        try image(of: frame, reading: .analysis(colorSpace: frame.colorSpace))
    }

    // MARK: - Private
    private func image(
        of frame: MediaFrame,
        reading: PictureReading
    ) throws -> CGImage {
        let file = MediaFile(media: frame.media)
        let kept = pictures.withLock { pictures in
            pictures[file.path]?.first { $0.index == frame.index && $0.reading == reading }?.image
        }
        if let kept { return kept }

        let image = try decoder.picture(of: file, atFrame: frame.index, reading: reading).cgImage()
        pictures.withLock { pictures in
            let others = (pictures[file.path] ?? []).filter { $0.index != frame.index || $0.reading != reading }
            pictures[file.path] = Array((others + [(frame.index, reading, image)]).suffix(Self.framesPerFile))
        }

        return image
    }
}
