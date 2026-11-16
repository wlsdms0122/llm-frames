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
// sequence draws a file's frames in order and a transition shows two of them.
final class MediaPictureCache: Sendable {
    // MARK: - Property
    private static let framesPerFile = 4

    private let decoder: any MediaDecoder
    private let pictures = OSAllocatedUnfairLock<[String: [(index: Int, image: CGImage)]]>(uncheckedState: [:])

    // MARK: - Initializer
    init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    func image(of frame: MediaFrame) throws -> CGImage {
        let file = MediaFile(media: frame.media)
        let kept = pictures.withLock { pictures in
            pictures[file.path]?.first { $0.index == frame.index }?.image
        }
        if let kept { return kept }

        let image = try decoder.picture(of: file, atFrame: frame.index).cgImage()
        pictures.withLock { pictures in
            let others = (pictures[file.path] ?? []).filter { $0.index != frame.index }
            pictures[file.path] = Array((others + [(frame.index, image)]).suffix(Self.framesPerFile))
        }

        return image
    }

    // MARK: - Private
}
