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
// sequence draws a file's frames in order and a transition shows two of them, and the last few pictures of each page.
// A frame is kept for each reading of it, and a page's picture for each region, scale and reading, so a picture is
// reused only for the very request a frame makes (FRAMES-20 Pictures).
final class MediaPictureCache: Sendable {
    // MARK: - Property
    private static let picturesPerFile = 4

    private let decoder: any MediaDecoder
    private let pictures = OSAllocatedUnfairLock<[String: [(picture: MediaPicture, reading: PictureReading, pixels: Pixels, image: CGImage)]]>(
        uncheckedState: [:]
    )
    private let pages = OSAllocatedUnfairLock<[String: [(request: PageRequest, image: CGImage)]]>(uncheckedState: [:])

    var largestPictureSide: Int {
        decoder.largestPictureSide
    }

    // MARK: - Initializer
    init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // The frame's picture as the decoder gives it for the frame, read as the frame says: working values, or an analysis
    // picture for a transition matte.
    func image(of frame: MediaFrame) throws -> CGImage {
        try picture(of: frame).image
    }

    // The frame's pixels as the decoder gives them, the same picture `image(of:)` gives.
    func pixels(of frame: MediaFrame) throws -> Pixels {
        try picture(of: frame).pixels
    }

    // `region` of the grid of the frame's page at `scale`, read as the frame says.
    func image(
        of frame: MediaFrame,
        region: PageRegion,
        scale: Double
    ) throws -> CGImage {
        let file = MediaFile(picture: frame.media)
        let request = PageRequest(page: file.page, region: region, scale: scale, reading: frame.reading)
        let kept = pages.withLock { pages in pages[file.path]?.first { $0.request == request }?.image }
        if let kept { return kept }

        let image = try decoder.picture(of: file, region: region, scale: scale, reading: frame.reading).bitmap.cgImage()
        pages.withLock { pages in
            let others = (pages[file.path] ?? []).filter { $0.request != request }
            pages[file.path] = Array((others + [(request, image)]).suffix(Self.picturesPerFile))
        }

        return image
    }

    // The size in media pixels of the frame's page.
    func pageSize(of frame: MediaFrame) throws -> Size {
        try decoder.pageSize(of: MediaFile(picture: frame.media))
    }

    // MARK: - Private
    private func picture(of frame: MediaFrame) throws -> (pixels: Pixels, image: CGImage) {
        let picture = frame.picture
        let reading = frame.reading
        let file = MediaFile(picture: frame.media)
        let kept = pictures.withLock { pictures in
            pictures[file.path]?.first { $0.picture == picture && $0.reading == reading }
        }
        if let kept { return (kept.pixels, kept.image) }

        let pixels = try decoder.picture(of: frame)
        let image = try pixels.bitmap.cgImage()
        pictures.withLock { pictures in
            let others = (pictures[file.path] ?? []).filter { $0.picture != picture || $0.reading != reading }
            pictures[file.path] = Array((others + [(picture, reading, pixels, image)]).suffix(Self.picturesPerFile))
        }

        return (pixels, image)
    }
}
