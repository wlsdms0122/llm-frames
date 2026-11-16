//
//  FrameExporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Takes frames out of a video or a resolved document without encoding a video. `still` draws sequence frames side by
// side at full size, `sheet` lays frames out on a grid, and `extract` writes each frame to a PNG of its own, named by
// its index. Everything that can refuse does before the first file is written, in this order: the output, the times,
// every pinned file's hash and the decoder on every pinned media (for a video, the decoder on it), and the renderer on
// every list it draws.
package struct FrameExporter: Sendable {
    // MARK: - Property
    // The longest side of a sheet's cell, so a sheet of many frames stays a picture one can open and read.
    private static let cellSide = 480.0

    private let decoder: any MediaDecoder
    private let renderer: any Renderer
    private let encoder: any Encoder
    private let mediaFacts: any MediaFactProvider
    private let hasher: any FileHashProvider
    private let pinned: PinnedReferenceChecker
    private let composer: ContactSheetComposer
    private let evaluator = Evaluator()

    // MARK: - Initializer
    // `shaper` and `library` set the labels.
    package init(
        decoder: any MediaDecoder,
        renderer: any Renderer,
        encoder: any Encoder,
        mediaFacts: any MediaFactProvider,
        shaper: any ShapingProvider,
        library: ReferenceLibrary
    ) {
        self.init(
            decoder: decoder,
            renderer: renderer,
            encoder: encoder,
            mediaFacts: mediaFacts,
            shaper: shaper,
            library: library,
            hasher: FileHasher()
        )
    }

    init(
        decoder: any MediaDecoder,
        renderer: any Renderer,
        encoder: any Encoder,
        mediaFacts: any MediaFactProvider,
        shaper: any ShapingProvider,
        library: ReferenceLibrary,
        hasher: any FileHashProvider
    ) {
        self.decoder = decoder
        self.renderer = renderer
        self.encoder = encoder
        self.mediaFacts = mediaFacts
        self.hasher = hasher
        self.pinned = PinnedReferenceChecker(decoder: decoder, hasher: hasher)
        self.composer = ContactSheetComposer(shaper: shaper, library: library, hasher: hasher)
    }

    // MARK: - Public
    // The sequence frames at `times`, in the order given, on one row at the sequence's size.
    package func still(
        _ document: ResolvedDocument,
        at times: [Double],
        to output: String
    ) throws {
        try checkOutput(output)
        let sequence = try sequence(of: document)
        guard !times.isEmpty else { throw ExportError.noTime }

        let duration = sequence.format.duration
        for time in times where time.timeTicks < 0 || time.timeTicks >= duration.timeTicks {
            throw ExportError.timeOutside(option: "--at", time: time, end: duration, kind: "sequence")
        }

        let frames = try frames(of: document, sequence: sequence, at: times)
        try draw(frames, size: frames.size, columns: times.count, to: output)
    }

    // The frames over `range` on a grid of `columns`, each scaled so its longer side is at most 480 pixels, never
    // enlarged.
    package func sheet(
        _ source: FrameSource,
        range: FrameRange,
        columns: Int,
        to output: String
    ) throws {
        try checkOutput(output)
        guard columns > 0 else { throw ExportError.nonPositiveColumns(columns) }

        let frames = try frames(of: source, range: range)
        let size = frames.size
        let scale = min(Self.cellSide / max(size.width, size.height), 1)
        let cell = Size(
            width: max((size.width * scale).rounded(), 1),
            height: max((size.height * scale).rounded(), 1)
        )
        try draw(frames, size: cell, columns: columns, to: output)
    }

    // The frames over `range` at full size and without labels, as `0000.png`, `0001.png` and on in time order in
    // `directory`, which is made when it is missing. Gives the files written, in that order.
    package func extract(
        _ source: FrameSource,
        range: FrameRange,
        to directory: String
    ) throws -> [String] {
        let frames = try frames(of: source, range: range).frames
        for case let .displayList(list) in frames.map(\.picture) {
            try renderer.check(list)
        }

        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            throw ExportError.unwritableDirectory(path: directory)
        }

        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        return try frames.enumerated().map { index, frame in
            let path = folder.appendingPathComponent(String(format: "%04d.png", index)).path
            try encoder.writeImage(try bitmap(of: frame.picture), to: path)

            return path
        }
    }

    // MARK: - Private
    private func draw(
        _ frames: SampledFrames,
        size: Size,
        columns: Int,
        to output: String
    ) throws {
        let sheet = try composer.sheet(of: frames.frames.map(ContactSheetCell.init), size: size, columns: columns)
        try renderer.check(sheet)

        try encoder.writeImage(try renderer.frame(of: sheet), to: output)
    }

    private func frames(
        of source: FrameSource,
        range: FrameRange
    ) throws -> SampledFrames {
        switch source {
        case let .video(path):
            return try frames(ofVideo: path, range: range)

        case let .document(document):
            let sequence = try sequence(of: document)
            let times = try range.times(end: sequence.format.duration, kind: "sequence")

            return try frames(of: document, sequence: sequence, at: times)
        }
    }

    // Composite frames at sequence times, as `render` draws them, once the files the document pins are checked.
    private func frames(
        of document: ResolvedDocument,
        sequence: ResolvedSequence,
        at times: [Double]
    ) throws -> SampledFrames {
        try pinned.check(document.pinnedReferences)

        return SampledFrames(
            size: sequence.format.size,
            frames: times.map { time in
                SampledFrame(time: time, picture: .displayList(evaluator.displayList(of: document, at: time)))
            }
        )
    }

    // The frames shown at media times, as a storyline clip shows them, once the decoder has checked the file.
    private func frames(
        ofVideo path: String,
        range: FrameRange
    ) throws -> SampledFrames {
        guard let probed = try mediaFacts.probedMedia(of: path) else { throw ExportError.missingMedia(path: path) }
        guard probed.kind == .video, let size = probed.size else {
            throw ExportError.notVideo(path: path, kind: probed.kind)
        }

        let times = try range.times(end: probed.duration, kind: "video")
        let file = MediaFile(path: path, fps: probed.fps, size: size, frameTimes: probed.frames)
        try decoder.check(file)

        let media = try PinnedMedia(file: file, hashes: hasher)
        return SampledFrames(
            size: size,
            frames: times.map { time in
                SampledFrame(time: time, picture: .media(MediaFrame(media: media, mediaTime: time)))
            }
        )
    }

    // Only a sequence has times, so an image or layout document has no frames to take.
    private func sequence(of document: ResolvedDocument) throws -> ResolvedSequence {
        switch document {
        case let .sequence(sequence):
            sequence

        case let .picture(picture):
            throw ExportError.timelessDocument(kind: picture.kind)
        }
    }

    // A media frame as the decoder reads it, so it is not resampled, and a display list as the renderer draws it.
    private func bitmap(of picture: PictureItemSource) throws -> Bitmap {
        switch picture {
        case let .media(frame):
            try decoder.picture(of: MediaFile(media: frame.media), atFrame: frame.index)

        case let .displayList(list):
            try renderer.frame(of: list)
        }
    }

    private func checkOutput(_ output: String) throws {
        guard URL(fileURLWithPath: output).pathExtension.lowercased() == "png" else {
            throw ExportError.outputExtension(path: output)
        }
    }
}
