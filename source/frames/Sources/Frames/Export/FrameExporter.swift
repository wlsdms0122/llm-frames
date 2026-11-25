//
//  FrameExporter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Takes frames out of a video, an image sequence or a resolved document without encoding a video. `still` draws sequence frames side by
// side at full size, `sheet` lays frames out on a grid, and `extract` writes each frame to a PNG of its own, named by
// its index. Everything that can refuse does before the first file is written, in this order: the output, the times,
// every pinned file's hash and the decoder on every pinned media (for a video, the decoder on it), and the renderer on
// every list it draws. Every file is an analysis picture (FRAMES-26), an 8-bit sRGB PNG whatever the sequence's colour
// space, and a label lies on the analysis picture of its frame.
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
        try draw(
            frames,
            in: sequence.format.output,
            size: frames.size,
            columns: times.count,
            labelFace: labelFace,
            to: output
        )
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
        try draw(frames, in: self.output(of: source), size: cell, columns: columns, labelFace: labelFace, to: output)
    }

    // The frames over `range` at full size and without labels, as `0000.png`, `0001.png` and on in time order in
    // `directory`, which is made when it is missing. Gives the files written, in that order.
    package func extract(
        _ source: FrameSource,
        range: FrameRange,
        to directory: String
    ) throws -> [String] {
        let frames = try frames(of: source, range: range).frames
        for frame in frames {
            guard case let .displayList(list) = frame.picture else { continue }

            try renderer.check(list, ofFrameAt: frame.time)
        }

        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            throw ExportError.unwritableDirectory(path: directory)
        }

        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        let output = output(of: source)
        return try frames.enumerated().map { index, frame in
            let path = folder.appendingPathComponent(String(format: "%04d.png", index)).path
            try encoder.writeAnalysisPicture(of: try bitmap(of: frame.picture), in: output, to: path)

            return path
        }
    }

    // MARK: - Private
    // A sequence frame of a colour space other than `srgb`, and one given as samples, is first drawn and written as its
    // analysis picture to a folder of its own, removed after, and drawn on the sheet from there, so its label lies on
    // the analysis picture and a frame with motion blur shows the mean of its samples (FRAMES-29), since a nested list
    // holds none. Any other frame's list is nested in the sheet: an `srgb` frame's analysis picture is its working
    // values clipped, which the sheet's output clips. A video's frame is read as its analysis picture.
    private func draw(
        _ frames: SampledFrames,
        in sequenceOutput: ColorConversion,
        size: Size,
        columns: Int,
        labelFace: FontFace,
        to output: String
    ) throws {
        let isDrawn = { (list: DisplayList) in
            switch list.content {
            case .items: sequenceOutput.space != .srgb
            case .samples: true
            }
        }
        let drawn = frames.frames.compactMap { frame -> (time: Double, list: DisplayList)? in
            guard case let .displayList(list) = frame.picture, isDrawn(list) else { return nil }

            return (frame.time, list)
        }
        for frame in drawn {
            try renderer.check(frame.list, ofFrameAt: frame.time)
        }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        if !drawn.isEmpty {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let cells = try frames.frames.enumerated().map { index, frame in
            guard case let .displayList(list) = frame.picture, isDrawn(list) else { return ContactSheetCell(frame) }

            let path = folder.appendingPathComponent("\(index).png").path
            try encoder.writeAnalysisPicture(of: renderer.frame(of: list), in: sequenceOutput, to: path)
            let media = try PinnedMedia(file: MediaFile(path: path, size: frames.size), hashes: hasher)

            let picture = MediaFrame(media: media, index: 0, reading: .analysis(colorSpace: nil))
            return ContactSheetCell(SampledFrame(time: frame.time, picture: .media(picture)))
        }
        let sheet = try composer.sheet(
            of: cells,
            size: size,
            columns: columns,
            face: labelFace
        )
        try renderer.check(sheet)

        try encoder.writeAnalysisPicture(of: try renderer.frame(of: sheet), in: ColorConversion(space: .srgb), to: output)
    }

    private func frames(
        of source: FrameSource,
        range: FrameRange
    ) throws -> SampledFrames {
        switch source {
        case let .video(path):
            return try frames(ofVideo: path, range: range)

        case let .imageSequence(directory, fps):
            guard let probed = try mediaFacts.probedImageSequence(at: directory) else {
                throw ExportError.missingMedia(path: directory)
            }
            let sequence = ImageSequence(probed: probed, directory: directory, fps: fps)

            return try frames(
                of: sequence.file,
                size: probed.size,
                times: try range.times(end: sequence.duration, kind: "image sequence")
            )

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

    // The frames of a video file at media times.
    private func frames(
        ofVideo path: String,
        range: FrameRange
    ) throws -> SampledFrames {
        guard let medium = try mediaFacts.probedMedium(of: path) else { throw ExportError.missingMedia(path: path) }
        guard case let .media(probed) = medium, probed.kind == .video, let size = probed.size else {
            throw ExportError.notVideo(path: path, kind: medium.kind)
        }

        let times = try range.times(end: probed.duration, kind: "video")
        let file = MediaFile(path: path, fps: probed.fps, size: size, frameTimes: probed.frames)

        return try frames(of: file, size: size, times: times)
    }

    // The frames of a video or an image sequence shown at media times, as a storyline clip shows them, each read as an
    // analysis picture, once the decoder has checked it reads the file's pictures so.
    private func frames(
        of file: MediaFile,
        size: Size,
        times: [Double]
    ) throws -> SampledFrames {
        try decoder.check(file, reading: .analysis(colorSpace: nil))

        let media = try PinnedMedia(file: file, hashes: hasher)
        return SampledFrames(
            size: size,
            frames: times.map { time in
                SampledFrame(
                    time: time,
                    picture: .media(MediaFrame(media: media, mediaTime: time, reading: .analysis(colorSpace: nil)))
                )
            }
        )
    }

    // A media frame as the decoder reads it, an analysis picture not resampled, and a display list as the renderer
    // draws it.
    private func bitmap(of picture: PictureItemSource) throws -> Bitmap {
        switch picture {
        case let .media(frame):
            try decoder.picture(of: frame)

        case let .displayList(list):
            try renderer.frame(of: list)
        }
    }

    // The output a source's frames are written by: a sequence's, and `srgb` for a video's or an image sequence's, which
    // the decoder reads as analysis pictures.
    private func output(of source: FrameSource) -> ColorConversion {
        switch source {
        case .video, .imageSequence:
            ColorConversion(space: .srgb)

        case let .document(sequence):
            sequence.format.output
        }
    }

    private func checkOutput(_ output: String) throws {
        guard URL(fileURLWithPath: output).pathExtension.lowercased() == "png" else {
            throw ExportError.outputExtension(path: output)
        }
    }
}
