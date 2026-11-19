//
//  RenderCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Renders a document through the roles the global options pick: the frame at `--at` to a PNG, or every frame to a
// master and, with `--deliver`, a delivery from the same frames.
struct RenderCommand: Command {
    // MARK: - Property
    let name = "render"
    let synopsis = "<document.json> -o <out.mov | out.png> [--at <t>] [--deliver <out.mp4>] [--args <args.json>]"
    let summary = "Renders a sequence: every frame to a .mov master, or the frame at --at to a .png at the frame's "
        + "size and without a time label."

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: RenderOptions,
        in context: CommandContext
    ) throws {
        let document = try context.document(options.document, arguments: options.arguments, command: name)
        let resolved = try document.resolved(in: context)
        let roles = context.roles
        let pipeline = RenderPipeline(
            decoder: roles.decoder,
            renderer: roles.renderer,
            mixer: roles.mixer,
            encoder: roles.encoder
        )

        try pipeline.render(resolved, to: options.output, at: options.time, delivery: options.delivery)
        for path in [options.output] + (options.delivery.map { [$0] } ?? []) {
            try context.reportWritten(path)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
