//
//  RenderPipeline.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Renders a resolved sequence through the roles: one frame of it to a PNG of 16 bits per channel, or every frame to a
// master and, when asked, a delivery from the same frames in the same pass, or to a delivery alone, each in the
// sequence's colour space and clipped to its peak. Everything that can refuse does before the first frame, in this
// order: the output paths and the time, every pinned file's hash, the decoder on every pinned media, the mixer on the
// mix plan, the renderer on every frame's display list, and the encoder on each target.
package struct RenderPipeline: Sendable {
    // MARK: - Property
    private let renderer: any Renderer
    private let mixer: any Mixer
    private let encoder: any Encoder
    private let pinned: PinnedReferenceChecker
    private let evaluator = Evaluator()

    // MARK: - Initializer
    package init(
        decoder: any MediaDecoder,
        renderer: any Renderer,
        mixer: any Mixer,
        encoder: any Encoder
    ) {
        self.init(decoder: decoder, renderer: renderer, mixer: mixer, encoder: encoder, hasher: FileHasher())
    }

    init(
        decoder: any MediaDecoder,
        renderer: any Renderer,
        mixer: any Mixer,
        encoder: any Encoder,
        hasher: any FileHashProvider
    ) {
        self.renderer = renderer
        self.mixer = mixer
        self.encoder = encoder
        self.pinned = PinnedReferenceChecker(decoder: decoder, hasher: hasher)
    }

    // MARK: - Public
    // `time` is the frame of a PNG, 0 when it is nil, and must be nil for a video. `delivery` goes beside a master
    // only.
    package func render(
        _ sequence: ResolvedSequence,
        to output: String,
        at time: Double?,
        delivery: String?
    ) throws {
        let format = sequence.format

        switch pathExtension(of: output) {
        case "png":
            if let delivery {
                throw RenderError.deliveryWithoutMaster(path: delivery)
            }
            try still(sequence, at: time ?? 0, to: output)

        case "mov":
            guard time == nil else { throw RenderError.timeOfVideo(path: output) }
            if let delivery, pathExtension(of: delivery) != "mp4" {
                throw RenderError.deliveryExtension(path: delivery)
            }

            let master = EncodeTarget.master(path: output, alpha: !format.background.isOpaque, output: format.output)
            let deliveries = delivery.map { [EncodeTarget.delivery(path: $0, output: format.output)] } ?? []
            try video(sequence, to: [master] + deliveries)

        case "mp4":
            guard time == nil else { throw RenderError.timeOfVideo(path: output) }
            if let delivery {
                throw RenderError.deliveryWithoutMaster(path: delivery)
            }

            try video(sequence, to: [.delivery(path: output, output: format.output)])

        default:
            throw RenderError.outputExtension(path: output)
        }
    }

    // MARK: - Private
    private func still(
        _ sequence: ResolvedSequence,
        at time: Double,
        to output: String
    ) throws {
        try FrameSpan(end: sequence.format.duration, kind: "sequence").check(time, option: "--at")

        try pinned.check(sequence.pinnedReferences)

        let list = evaluator.displayList(of: sequence, at: time)
        try renderer.check(list, ofFrameAt: time)
        let target = ImageTarget.png(
            path: output,
            size: sequence.format.size,
            depth: .sixteen,
            output: sequence.format.output
        )
        try encoder.check(target)

        try encoder.writeImage(renderer.frame(of: list), for: target)
    }

    // Draws every frame once and appends it to each target's writer.
    private func video(
        _ sequence: ResolvedSequence,
        to targets: [EncodeTarget]
    ) throws {
        let mix = try SequenceMix(of: sequence, pinned: pinned, mixer: mixer)

        let format = sequence.format
        let times = (0..<format.frameCount).map(format.frameTime)
        for time in times {
            try renderer.check(evaluator.displayList(of: sequence, at: time), ofFrameAt: time)
        }

        for target in targets {
            try encoder.check(target)
        }

        // A sequence without sound mixes to silence, so every master and delivery carries one sound track.
        let sound = try mix.mixed()
        let writers = try targets.map { target in
            try encoder.videoWriter(for: target, size: format.size, fps: format.fps, sound: sound)
        }

        for time in times {
            let frame = try renderer.frame(of: evaluator.displayList(of: sequence, at: time))
            for writer in writers {
                try writer.append(frame)
            }
        }
        for writer in writers {
            try writer.finish()
        }
    }

    private func pathExtension(of path: String) -> String {
        URL(fileURLWithPath: path).pathExtension.lowercased()
    }
}
