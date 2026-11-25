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
// mix plan, the renderer on every frame's display list, and the encoder on each target. A run's recorder times each
// stage the pipeline runs and the time it spends in the encoder, and is told of every frame drawn (FRAMES-23 Runs). The
// run's budget is given the floors of the frames in flight and of the mixed sound once the roles have checked
// everything, and a limit under the run's floor is refused there, in `check` (FRAMES-30 The budget). It counts the
// frame being drawn while a video is written, and the write queue the frames it holds.
package struct RenderPipeline: Sendable {
    // MARK: - Property
    private let decoder: any MediaDecoder
    private let renderer: any Renderer
    private let mixer: any Mixer
    private let encoder: any Encoder
    private let budget: MemoryBudget
    private let pinned: PinnedReferenceChecker
    private let evaluator = Evaluator()

    // MARK: - Initializer
    package init(
        decoder: any MediaDecoder,
        renderer: any Renderer,
        mixer: any Mixer,
        encoder: any Encoder,
        budget: MemoryBudget
    ) {
        self.init(
            decoder: decoder,
            renderer: renderer,
            mixer: mixer,
            encoder: encoder,
            budget: budget,
            hasher: FileHasher()
        )
    }

    init(
        decoder: any MediaDecoder,
        renderer: any Renderer,
        mixer: any Mixer,
        encoder: any Encoder,
        budget: MemoryBudget,
        hasher: any FileHashProvider
    ) {
        self.decoder = decoder
        self.renderer = renderer
        self.mixer = mixer
        self.encoder = encoder
        self.budget = budget
        self.pinned = PinnedReferenceChecker(decoder: decoder, hasher: hasher)
    }

    // MARK: - Public
    // `time` is the frame of a PNG, 0 when it is nil, and must be nil for a video. `delivery` goes beside a master
    // only.
    @discardableResult
    package func render(
        _ sequence: ResolvedSequence,
        to output: String,
        at time: Double?,
        delivery: String?,
        recorder: RunRecorder = RunRecorder()
    ) throws -> RenderRun {
        let format = sequence.format

        switch pathExtension(of: output) {
        case "png":
            if let delivery {
                throw RenderError.deliveryWithoutMaster(path: delivery)
            }
            return try still(sequence, at: time ?? 0, to: output, recorder: recorder)

        case "mov":
            guard time == nil else { throw RenderError.timeOfVideo(path: output) }
            if let delivery, pathExtension(of: delivery) != "mp4" {
                throw RenderError.deliveryExtension(path: delivery)
            }

            let master = EncodeTarget.master(path: output, alpha: !format.background.isOpaque, output: format.output)
            let deliveries = delivery.map { [EncodeTarget.delivery(path: $0, output: format.output)] } ?? []
            return try video(sequence, to: [master] + deliveries, recorder: recorder)

        case "mp4":
            guard time == nil else { throw RenderError.timeOfVideo(path: output) }
            if let delivery {
                throw RenderError.deliveryWithoutMaster(path: delivery)
            }

            return try video(sequence, to: [.delivery(path: output, output: format.output)], recorder: recorder)

        default:
            throw RenderError.outputExtension(path: output)
        }
    }

    // MARK: - Private
    private func still(
        _ sequence: ResolvedSequence,
        at time: Double,
        to output: String,
        recorder: RunRecorder
    ) throws -> RenderRun {
        try FrameSpan(end: sequence.format.duration, kind: "sequence").check(time, option: "--at")

        try recorder.measure(.check, reading: decoder) { try pinned.check(sequence.pinnedReferences) }

        let list = recorder.measure(.evaluate, reading: decoder) { evaluator.displayList(of: sequence, at: time) }
        let target = ImageTarget.png(
            path: output,
            size: sequence.format.size,
            depth: .sixteen,
            output: sequence.format.output
        )
        try recorder.measure(.check, reading: decoder) {
            try renderer.check(list, ofFrameAt: time)
            try encoder.check(target)
            budget.require(frameBytes(of: sequence.format), for: .frames)
            try budget.checkFloor()
        }

        let frame = try recorder.measure(.draw, reading: decoder) { try renderer.frame(of: list) }
        let file = try recorder.measureWaitingOnEncoder { try encoder.writeImage(frame.bitmap, for: target) }
        recorder.drew(frame: 1, of: 1)

        return RenderRun(frames: 1, files: [file])
    }

    // Draws every frame once and appends it to each target's writer, which writes it while the next is drawn.
    private func video(
        _ sequence: ResolvedSequence,
        to targets: [EncodeTarget],
        recorder: RunRecorder
    ) throws -> RenderRun {
        let mix = try recorder.measure(.check, reading: decoder) {
            try SequenceMix(of: sequence, pinned: pinned, mixer: mixer)
        }
        let soundBytes = mix.plan.length * 2 * MemoryLayout<Float>.size

        let format = sequence.format
        let times = (0..<format.frameCount).map(format.frameTime)
        for time in times {
            let list = recorder.measure(.evaluate, reading: decoder) { evaluator.displayList(of: sequence, at: time) }
            try recorder.measure(.check, reading: decoder) { try renderer.check(list, ofFrameAt: time) }
        }

        try recorder.measure(.check, reading: decoder) {
            for target in targets {
                try encoder.check(target)
            }
            budget.require(2 * frameBytes(of: format), for: .frames)
            budget.require(soundBytes, for: .sound)
            try budget.checkFloor()
        }

        // A sequence without sound mixes to silence, so every master and delivery carries one sound track.
        let sound = try recorder.measure(.mix, reading: decoder) { try mix.mixed() }
        let writers = try recorder.measureWaitingOnEncoder {
            try targets.map { target in
                try encoder.videoWriter(for: target, size: format.size, fps: format.fps, sound: sound)
            }
        }

        let queue = FrameWriteQueue(writers: writers, budget: budget, frameBytes: frameBytes(of: format))
        budget.hold(frameBytes(of: format), for: .frames)
        defer { budget.give(frameBytes(of: format), for: .frames) }
        do {
            for (index, time) in times.enumerated() {
                let list = recorder.measure(.evaluate, reading: decoder) {
                    evaluator.displayList(of: sequence, at: time)
                }
                let frame = try recorder.measure(.draw, reading: decoder) { try renderer.frame(of: list) }
                try recorder.measureWaitingOnEncoder { try queue.append(frame) }
                recorder.drew(frame: index + 1, of: times.count)
            }
            try recorder.measureWaitingOnEncoder { try queue.finish() }
        } catch {
            queue.cancel()
            throw error
        }

        return RenderRun(frames: times.count, files: writers.map(\.encoding))
    }

    // The bytes of one output frame of working values, RGBA half floats.
    private func frameBytes(of format: ResolvedFormat) -> Int {
        Int(format.size.width) * Int(format.size.height) * 4 * MemoryLayout<UInt16>.size
    }

    private func pathExtension(of path: String) -> String {
        URL(fileURLWithPath: path).pathExtension.lowercased()
    }
}
