//
//  RenderCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Renders a document through the roles the global options pick: an image or layout to a PNG, and a sequence to a
// master and, with `--deliver`, a delivery from the same frames.
struct RenderCommand: Command {
    // MARK: - Property
    let name = "render"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: RenderOptions,
        in context: CommandContext
    ) throws {
        let document = try context.document(options.document, arguments: options.arguments, command: name)
        let resolved = try document.resolved(by: context.planner)
        let roles = context.roles
        let pipeline = RenderPipeline(
            decoder: roles.decoder,
            renderer: roles.renderer,
            mixer: roles.mixer,
            encoder: roles.encoder
        )

        try pipeline.render(resolved, to: options.output, delivery: options.delivery)
        for path in [options.output] + (options.delivery.map { [$0] } ?? []) {
            try context.reportWritten(path)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
