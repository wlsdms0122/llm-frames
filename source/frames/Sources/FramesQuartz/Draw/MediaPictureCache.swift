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
// last and those the frame being drawn has read. The run's budget counts every picture kept as its `pictures` hold,
// which the frames need and so is never refused (FRAMES-30 The budget).
final class MediaPictureCache: Sendable {
    // MARK: - Property
    private let decoder: any MediaDecoder
    private let budget: MemoryBudget
    private let pictures = OSAllocatedUnfairLock<[Kept<PictureRequest, (pixels: Pixels, image: CGImage)>]>(
        uncheckedState: []
    )
    private let pages = OSAllocatedUnfairLock<[Kept<PageKey, CGImage>]>(uncheckedState: [])

    var largestPictureSide: Int {
        decoder.largestPictureSide
    }

    // MARK: - Initializer
    init(
        decoder: any MediaDecoder,
        budget: MemoryBudget
    ) {
        self.decoder = decoder
        self.budget = budget
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

    // The frame's picture as a source drawn, read where it lies on the GPU where the decoder gave a surface.
    func source(of frame: MediaFrame) throws -> SourceImage {
        let picture = try picture(of: frame)

        return SourceImage(media: picture.image, pixels: picture.pixels)
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
        keep(image, bytes: image.bytesPerRow * image.height, for: key, in: pages)

        return image
    }

    // The size in media pixels of the frame's page.
    func pageSize(of frame: MediaFrame) throws -> Size {
        try decoder.pageSize(of: MediaFile(picture: frame.media))
    }

    // Lets go of every picture the frame drawn last did not use, and counts the rest unused by the next frame.
    func frameDrawn() {
        drop(in: pictures)
        drop(in: pages)
    }

    // MARK: - Private
    private func picture(of frame: MediaFrame) throws -> (pixels: Pixels, image: CGImage) {
        let file = MediaFile(picture: frame.media)
        let request = PictureRequest(path: file.path, picture: frame.picture, reading: frame.reading)
        if let kept = Self.use(request, in: pictures) { return kept }

        let pixels = try decoder.picture(of: frame)
        let bitmap = pixels.bitmap
        let picture = (pixels: pixels, image: try bitmap.cgImage())
        keep(picture, bytes: bitmap.bytesPerRow * bitmap.height, for: request, in: pictures)

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

    // `value` of `bytes` kept for `key`, used by the frame being drawn, in place of any value kept for it before.
    private func keep<Key: Equatable, Value>(
        _ value: Value,
        bytes: Int,
        for key: Key,
        in kept: OSAllocatedUnfairLock<[Kept<Key, Value>]>
    ) {
        let replaced = kept.withLockUnchecked { kept in
            let replaced = kept.filter { $0.key == key }.reduce(0) { $0 + $1.bytes }
            kept.removeAll { $0.key == key }
            kept.append(Kept(key: key, value: value, bytes: bytes, isUsed: true))

            return replaced
        }
        budget.give(replaced, for: .pictures)
        budget.hold(bytes, for: .pictures)
    }

    private func drop<Key, Value>(in kept: OSAllocatedUnfairLock<[Kept<Key, Value>]>) {
        let dropped = kept.withLockUnchecked { kept in
            let dropped = kept.filter { !$0.isUsed }.reduce(0) { $0 + $1.bytes }
            kept.removeAll { !$0.isUsed }
            for index in kept.indices {
                kept[index].isUsed = false
            }

            return dropped
        }
        budget.give(dropped, for: .pictures)
    }
}

extension MediaPictureCache {
    // A picture kept, its bytes, and whether the frame being drawn has used it.
    private struct Kept<Key, Value> {
        let key: Key
        let value: Value
        let bytes: Int
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
