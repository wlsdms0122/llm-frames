//
//  RenderPipeline.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Renders a resolved sequence through the roles: one frame of it to a PNG of 16 bits per channel, or every frame to a
// master and, when asked, a delivery from the same frames in the same pass, each in the sequence's colour space and
// clipped to its peak. Everything that can refuse does before the first frame, in this order: the output paths and the
// time, every pinned file's hash, the decoder on every pinned media, the mixer on the mix plan, the renderer on every
// frame's display list, and the encoder on each target.
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
    // `time` is the frame of a PNG, 0 when it is nil, and must be nil for a master.
    package func render(
        _ sequence: ResolvedSequence,
        to output: String,
        at time: Double?,
        delivery: String?
    ) throws {
        switch pathExtension(of: output) {
        case "png":
            try still(sequence, at: time ?? 0, to: output, delivery: delivery)

        case "mov":
            guard time == nil else { throw RenderError.timeOfMaster(path: output) }
            try master(sequence, to: output, delivery: delivery)

        default:
            throw RenderError.outputExtension(path: output)
        }
    }

    // MARK: - Private
    private func still(
        _ sequence: ResolvedSequence,
        at time: Double,
        to output: String,
        delivery: String?
    ) throws {
        if let delivery {
            throw RenderError.deliveryOfStill(path: delivery)
        }
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

    private func master(
        _ sequence: ResolvedSequence,
        to output: String,
        delivery: String?
    ) throws {
        if let delivery, pathExtension(of: delivery) != "mp4" {
            throw RenderError.deliveryExtension(path: delivery)
        }

        let mix = try SequenceMix(of: sequence, pinned: pinned, mixer: mixer)

        let format = sequence.format
        let times = (0..<format.frameCount).map(format.frameTime)
        for time in times {
            try renderer.check(evaluator.displayList(of: sequence, at: time), ofFrameAt: time)
        }

        let master = EncodeTarget.master(path: output, alpha: !format.background.isOpaque, output: format.output)
        let targets = [master] + (delivery.map { [EncodeTarget.delivery(path: $0, output: format.output)] } ?? [])
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
