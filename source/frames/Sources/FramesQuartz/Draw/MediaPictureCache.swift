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
// is shown on every frame of its clip. A frame is kept for each reading of it whichever play asks it, so a frame two
// clips show in one frame, or in two frames one after the other, is read once and the play that asks it second asks
// the decoder nothing, while two clips that show it further apart read it each (FRAMES-21 Rules), and a page's picture
// for each region, scale and reading, so a picture is reused only for the very request a frame makes (FRAMES-20
// Pictures). Once a frame is drawn, `frameDrawn()` lets go of every picture it did not use, so the pictures kept are
// those of the frame drawn last and those the frame being drawn has read, and gives the decoder the media frames the
// frame asked for, those it took from the pictures kept among them, so the decoder ends the plays it did not show. The run's budget counts every picture of pixels kept, a frame's
// picture of its displayed size at 8 bytes a pixel as working values and 4 as an analysis picture, as its `pictures`
// hold, which is never refused and stays within the floor `reserve(for:)` gives for every list checked before it is
// drawn. A page's pictures are not counted (FRAMES-30 The budget).
final class MediaPictureCache: Sendable {
    // MARK: - Property
    private let decoder: any MediaDecoder
    private let budget: MemoryBudget
    private let pictures = OSAllocatedUnfairLock<[Kept<PictureRequest, (pixels: Pixels, image: CGImage)>]>(
        uncheckedState: []
    )
    private let pages = OSAllocatedUnfairLock<[Kept<PageKey, CGImage>]>(uncheckedState: [])
    private let sizes = OSAllocatedUnfairLock<[String: Size]>(initialState: [:])
    // The media frames the frame being drawn has asked for, in the order it asked them.
    private let shown = OSAllocatedUnfairLock<[MediaFrame]>(initialState: [])

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
    // Raises the budget's `pictures` floor to twice the bytes of the pictures of pixels `list` reads, each once, since
    // the pictures of the frame drawn last are kept beside those of the frame being drawn.
    func reserve(for list: DisplayList) throws {
        budget.require(2 * (try bytes(of: list)), for: .pictures)
    }

    // The bytes the budget counts the pictures of pixels `list` reads at, each once.
    func bytes(of list: DisplayList) throws -> Int {
        try MediaPictureFinder().frames(of: list).reduce(0) { total, frame in
            let size = try pictureSize(of: MediaFile(picture: frame.media))

            return total + Self.bytes(width: Int(size.width), height: Int(size.height), reading: frame.reading)
        }
    }

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
        shown.withLock { $0.append(frame) }
        let file = MediaFile(picture: frame.media)
        let key = PageKey(
            path: file.path,
            request: PageRequest(page: file.page, region: region, scale: scale, reading: frame.reading)
        )
        if let kept = Self.use(key, in: pages) { return kept }

        let image = try decoder.picture(of: file, region: region, scale: scale, reading: frame.reading).bitmap.cgImage()
        _ = keep(image, bytes: image.bytesPerRow * image.height, for: key, in: pages)

        return image
    }

    // The size in media pixels of the frame's page.
    func pageSize(of frame: MediaFrame) throws -> Size {
        try decoder.pageSize(of: MediaFile(picture: frame.media))
    }

    // Lets go of every picture the frame drawn last did not use, counts the rest unused by the next frame, and gives
    // the decoder the media frames the frame drawn last asked for.
    func frameDrawn() {
        budget.give(drop(in: pictures), for: .pictures)
        _ = drop(in: pages)
        decoder.frameRendered(showing: shown.withLock { shown in
            defer { shown = [] }

            return shown
        })
    }

    // MARK: - Private
    private func picture(of frame: MediaFrame) throws -> (pixels: Pixels, image: CGImage) {
        shown.withLock { $0.append(frame) }
        let file = MediaFile(picture: frame.media)
        let request = PictureRequest(path: file.path, picture: frame.picture, reading: frame.reading)
        if let kept = Self.use(request, in: pictures) { return kept }

        let pixels = try decoder.picture(of: frame)
        let picture = (pixels: pixels, image: try pixels.bitmap.cgImage())
        let bytes = Self.bytes(width: pixels.width, height: pixels.height, reading: frame.reading)
        budget.give(keep(picture, bytes: bytes, for: request, in: pictures), for: .pictures)
        budget.hold(bytes, for: .pictures)

        return picture
    }

    // The displayed size of the pictures of `file`, asked of the decoder once.
    private func pictureSize(of file: MediaFile) throws -> Size {
        if let size = sizes.withLock({ $0[file.path] }) { return size }

        let size = try decoder.pictureSize(of: file)
        sizes.withLock { $0[file.path] = size }

        return size
    }

    // The bytes the budget counts a picture of pixels at: RGBA, half floats as working values and 8 bits as an analysis
    // picture (FRAMES-21 Pictures).
    private static func bytes(
        width: Int,
        height: Int,
        reading: PictureReading
    ) -> Int {
        let depth: BitDepth = switch reading {
        case .working, .platform:
            .halfFloat

        case .analysis:
            .eight
        }

        return width * height * 4 * depth.bitsPerComponent / 8
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

    // `value` of `bytes` kept for `key`, used by the frame being drawn, in place of any value kept for it before, whose
    // bytes it gives.
    private func keep<Key: Equatable, Value>(
        _ value: Value,
        bytes: Int,
        for key: Key,
        in kept: OSAllocatedUnfairLock<[Kept<Key, Value>]>
    ) -> Int {
        kept.withLockUnchecked { kept in
            let replaced = kept.filter { $0.key == key }.reduce(0) { $0 + $1.bytes }
            kept.removeAll { $0.key == key }
            kept.append(Kept(key: key, value: value, bytes: bytes, isUsed: true))

            return replaced
        }
    }

    // Lets go of every value the frame drawn last did not use, and gives their bytes.
    private func drop<Key, Value>(in kept: OSAllocatedUnfairLock<[Kept<Key, Value>]>) -> Int {
        kept.withLockUnchecked { kept in
            let dropped = kept.filter { !$0.isUsed }.reduce(0) { $0 + $1.bytes }
            kept.removeAll { !$0.isUsed }
            for index in kept.indices {
                kept[index].isUsed = false
            }

            return dropped
        }
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

    // A frame's picture of a file, read as its frame says, in any play.
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
