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
    // `shaper` sets the time labels of `still` and `sheet`.
    package init(
        decoder: any MediaDecoder,
        renderer: any Renderer,
        encoder: any Encoder,
        mediaFacts: any MediaFactProvider,
        shaper: any ShapingProvider
    ) {
        self.init(
            decoder: decoder,
            renderer: renderer,
            encoder: encoder,
            mediaFacts: mediaFacts,
            shaper: shaper,
            hasher: FileHasher()
        )
    }

    init(
        decoder: any MediaDecoder,
        renderer: any Renderer,
        encoder: any Encoder,
        mediaFacts: any MediaFactProvider,
        shaper: any ShapingProvider,
        hasher: any FileHashProvider
    ) {
        self.decoder = decoder
        self.renderer = renderer
        self.encoder = encoder
        self.mediaFacts = mediaFacts
        self.hasher = hasher
        self.pinned = PinnedReferenceChecker(decoder: decoder, hasher: hasher)
        self.composer = ContactSheetComposer(shaper: shaper, hasher: hasher)
    }

    // MARK: - Public
    // The sequence frames at `times`, in the order given, on one row at the sequence's size, labelled in `labelFace`.
    package func still(
        _ sequence: ResolvedSequence,
        at times: [Double],
        labelFace: FontFace,
        to output: String
    ) throws {
        try checkOutput(output)
        guard !times.isEmpty else { throw ExportError.noTime }

        let span = FrameSpan(end: sequence.format.duration, kind: "sequence")
        for time in times {
            try span.check(time, option: "--at")
        }

        let frames = try frames(of: sequence, at: times)
        try draw(frames, size: frames.size, columns: times.count, labelFace: labelFace, to: output)
    }

    // The frames over `range` on a grid of `columns`, each scaled so its longer side is at most 480 pixels, never
    // enlarged, labelled in `labelFace`.
    package func sheet(
        _ source: FrameSource,
        range: FrameRange,
        columns: Int,
        labelFace: FontFace,
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
        try draw(frames, size: cell, columns: columns, labelFace: labelFace, to: output)
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
        labelFace: FontFace,
        to output: String
    ) throws {
        let sheet = try composer.sheet(
            of: frames.frames.map(ContactSheetCell.init),
            size: size,
            columns: columns,
            face: labelFace
        )
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

        case let .document(sequence):
            let times = try range.times(end: sequence.format.duration, kind: "sequence")

            return try frames(of: sequence, at: times)
        }
    }

    // Composite frames at sequence times, as `render` draws them, once the files the sequence pins are checked.
    private func frames(
        of sequence: ResolvedSequence,
        at times: [Double]
    ) throws -> SampledFrames {
        try pinned.check(sequence.pinnedReferences)

        return SampledFrames(
            size: sequence.format.size,
            frames: times.map { time in
                SampledFrame(time: time, picture: .displayList(evaluator.displayList(of: sequence, at: time)))
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

    // A media frame as the decoder reads it, an analysis picture not resampled, and a display list as the renderer
    // draws it.
    private func bitmap(of picture: PictureItemSource) throws -> Bitmap {
        switch picture {
        case let .media(frame):
            try decoder.analysisPicture(of: frame)

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
