//
//  MediaPictureCache.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Frames
import os

// Media pictures read through the decoder, kept from the frame that read them to the next: a frame shows a file's
// frame again where its clip is slower than the sequence's rate, a transition shows two frames of one file, and a page
// is shown on every frame of its clip. A frame is kept for each reading of it, and a page's picture for each region,
// scale and reading, so a picture is reused only for the very request a frame makes (FRAMES-20 Pictures). Once a frame
// is drawn, `frameDrawn()` lets go of every picture it did not use, so the pictures kept are those of the frame drawn
// last and those the frame being drawn has read.
final class MediaPictureCache: Sendable {
    // MARK: - Property
    private let decoder: any MediaDecoder
    private let pictures = OSAllocatedUnfairLock<[Kept<PictureRequest, (pixels: Pixels, image: CGImage)>]>(
        uncheckedState: []
    )
    private let pages = OSAllocatedUnfairLock<[Kept<PageKey, CGImage>]>(uncheckedState: [])

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
        let key = PageKey(
            path: file.path,
            request: PageRequest(page: file.page, region: region, scale: scale, reading: frame.reading)
        )
        if let kept = Self.use(key, in: pages) { return kept }

        let image = try decoder.picture(of: file, region: region, scale: scale, reading: frame.reading).bitmap.cgImage()
        Self.keep(image, for: key, in: pages)

        return image
    }

    // The size in media pixels of the frame's page.
    func pageSize(of frame: MediaFrame) throws -> Size {
        try decoder.pageSize(of: MediaFile(picture: frame.media))
    }

    // Lets go of every picture the frame drawn last did not use, and counts the rest unused by the next frame.
    func frameDrawn() {
        Self.drop(in: pictures)
        Self.drop(in: pages)
    }

    // MARK: - Private
    private func picture(of frame: MediaFrame) throws -> (pixels: Pixels, image: CGImage) {
        let file = MediaFile(picture: frame.media)
        let request = PictureRequest(path: file.path, picture: frame.picture, reading: frame.reading)
        if let kept = Self.use(request, in: pictures) { return kept }

        let pixels = try decoder.picture(of: frame)
        let picture = (pixels: pixels, image: try pixels.bitmap.cgImage())
        Self.keep(picture, for: request, in: pictures)

        return picture
    }

    // The value kept for `key`, counted used by the frame being drawn.
    private static func use<Key: Equatable, Value>(
        _ key: Key,
        in kept: OSAllocatedUnfairLock<[Kept<Key, Value>]>
    ) -> Value? {
        kept.withLockUnchecked { kept in
            guard let index = kept.firstIndex(where: { $0.key == key }) else { return nil }
            kept[index].isUsed = true

            return kept[index].value
        }
    }

    // `value` kept for `key`, used by the frame being drawn, in place of any value kept for it before.
    private static func keep<Key: Equatable, Value>(
        _ value: Value,
        for key: Key,
        in kept: OSAllocatedUnfairLock<[Kept<Key, Value>]>
    ) {
        kept.withLockUnchecked { kept in
            kept.removeAll { $0.key == key }
            kept.append(Kept(key: key, value: value, isUsed: true))
        }
    }

    private static func drop<Key, Value>(in kept: OSAllocatedUnfairLock<[Kept<Key, Value>]>) {
        kept.withLockUnchecked { kept in
            kept.removeAll { !$0.isUsed }
            for index in kept.indices {
                kept[index].isUsed = false
            }
        }
    }
}

extension MediaPictureCache {
    // A picture kept, and whether the frame being drawn has used it.
    private struct Kept<Key, Value> {
        let key: Key
        let value: Value
        var isUsed: Bool
    }

    // A frame's picture of a file, read as its frame says.
    private struct PictureRequest: Equatable {
        let path: String
        let picture: MediaPicture
        let reading: PictureReading
    }

    // A page's picture of a file.
    private struct PageKey: Equatable {
        let path: String
        let request: PageRequest
    }
}
