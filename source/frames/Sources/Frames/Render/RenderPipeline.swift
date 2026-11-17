//
//  RenderPipeline.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Renders a resolved document through the roles: an image or layout to one PNG, and a sequence to a master and, when
// asked, a delivery from the same frames in the same pass. Everything that can refuse does before the first frame,
// in this order: the output paths, every pinned file's hash, the decoder on every pinned media, the renderer on every
// frame's display list, the mixer on the mix plan, and the encoder on each target.
package struct RenderPipeline: Sendable {
    // MARK: - Property
    private let renderer: any Renderer
    private let mixer: any Mixer
    private let encoder: any Encoder
    private let pinned: PinnedReferenceChecker
    private let evaluator = Evaluator()
    private let planner = MixPlanner()

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
    package func render(
        _ document: ResolvedDocument,
        to output: String,
        delivery: String?
    ) throws {
        switch document {
        case let .sequence(sequence):
            try render(sequence, of: document, to: output, delivery: delivery)

        case let .picture(picture):
            try render(picture, of: document, to: output, delivery: delivery)
        }
    }

    // MARK: - Private
    private func render(
        _ picture: ResolvedPicture,
        of document: ResolvedDocument,
        to output: String,
        delivery: String?
    ) throws {
        guard pathExtension(of: output) == "png" else {
            throw RenderError.outputExtension(path: output, kind: picture.kind, expected: "png")
        }
        if let delivery {
            throw RenderError.deliveryOfPicture(path: delivery, kind: picture.kind)
        }

        try pinned.check(document.pinnedReferences)

        let list = evaluator.displayList(of: document, at: 0)
        try renderer.check(list)

        try encoder.writeImage(renderer.frame(of: list), to: output)
    }

    private func render(
        _ sequence: ResolvedSequence,
        of document: ResolvedDocument,
        to output: String,
        delivery: String?
    ) throws {
        guard pathExtension(of: output) == "mov" else {
            throw RenderError.outputExtension(path: output, kind: "sequence", expected: "mov")
        }
        if let delivery, pathExtension(of: delivery) != "mp4" {
            throw RenderError.deliveryExtension(path: delivery)
        }

        try pinned.check(document.pinnedReferences)

        let format = sequence.format
        let times = (0..<format.frameCount).map(format.frameTime)
        for time in times {
            try renderer.check(evaluator.displayList(of: document, at: time))
        }

        let plan = planner.mix(of: sequence)
        try mixer.check(plan)

        let master = EncodeTarget.master(path: output, alpha: !format.background.isOpaque)
        let targets = [master] + (delivery.map { [EncodeTarget.delivery(path: $0)] } ?? [])
        for target in targets {
            try encoder.check(target)
        }

        // A sequence without sound gets silence, so every master and delivery carries the same tracks.
        let sound = try mixer.mix(plan, duration: format.renderedDuration)
        let writers = try targets.map { target in
            try encoder.videoWriter(for: target, size: format.size, fps: format.fps, sound: sound)
        }

        for time in times {
            let frame = try renderer.frame(of: evaluator.displayList(of: document, at: time))
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
