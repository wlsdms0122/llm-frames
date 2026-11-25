//
//  RenderCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import FramesAVFoundation

// Renders a document through the roles the global options pick: the frame at `--at` to a PNG, every frame to a master
// and, with `--deliver`, a delivery from the same frames, or every frame to a delivery alone. It writes its progress on
// standard error, marks each stage of the run with a signpost, and with `--report` writes the run's report when its
// last file is closed (FRAMES-23 Runs).
struct RenderCommand: Command {
    // MARK: - Property
    let name = "render"
    let synopsis = "<document.json> -o <out.mov | out.mp4 | out.png> [--at <t>] [--deliver <out.mp4>] "
        + "[--args <args.json>] [--report <report.json>] [--progress text|json|none]"
    let summary = "Renders a sequence: every frame to a .mov master or to an .mp4 delivery alone, or the frame at --at "
        + "to a .png at the frame's size and without a time label."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: RenderOptions,
        in context: CommandContext
    ) throws {
        let outputs = [options.output] + (options.delivery.map { [$0] } ?? [])
        if let report = options.report {
            guard URL(fileURLWithPath: report).pathExtension.lowercased() == "json" else {
                throw CommandError.reportExtension(path: report)
            }
            // Paths are compared as files, so `./out.mov` is `out.mov`.
            let file = { (path: String) in URL(fileURLWithPath: path).standardizedFileURL.path }
            guard !outputs.map(file).contains(file(report)) else { throw CommandError.reportOverOutput(path: report) }
        }

        let usage = ProcessUsage()
        let progress = ProgressWriter(format: options.progress, output: context.output)
        let recorder = RunRecorder(marker: StageSignposter(), progress: { progress.write($0) })
        let roles = context.roles
        let resolved = try recorder.measure(.resolve, reading: roles.decoder) {
            try context.document(options.document, arguments: options.arguments, command: name).resolved(in: context)
        }
        let pipeline = RenderPipeline(
            decoder: roles.decoder,
            renderer: roles.renderer,
            mixer: roles.mixer,
            encoder: roles.encoder
        )

        let run = try pipeline.render(
            resolved,
            to: options.output,
            at: options.time,
            delivery: options.delivery,
            recorder: recorder
        )
        // The decoder's readings are taken as the run ends, so they hold the work that ended within it.
        let readings = roles.decoder.readings()
        let seconds = recorder.elapsed
        let ended = ProcessUsage()
        for path in outputs {
            try context.reportWritten(path)
        }
        guard let report = options.report else { return }

        let written = RunReport(
            run: run,
            seconds: seconds,
            cpuSeconds: ended.cpuSeconds - usage.cpuSeconds,
            peakMemory: ended.peakMemory,
            machine: .current,
            roles: RoleFactory().names(for: context.options),
            recorder: recorder,
            readings: readings
        )
        try context.write(JSONWriter().write(written.machineOutput), to: report)
        try context.reportWritten(report)
    }

    // MARK: - Public
    // MARK: - Private
}
