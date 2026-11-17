//
//  TranscodeCommand.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// Writes a media file again, smaller, with the encoder role, and prints its line: path, size, format and the size
// against the source's.
struct TranscodeCommand: Command {
    // MARK: - Property
    let name = "transcode"

    // MARK: - Initializer
    init() { }

    // MARK: - Lifecycle
    func run(
        _ options: TranscodeOptions,
        in context: CommandContext
    ) throws {
        let roles = context.roles
        let transcoder = Transcoder(decoder: roles.decoder, facts: roles.decoder, encoder: roles.encoder)

        context.output.write(TranscodeLine(try transcoder.transcode(options.request)).description + "\n")
    }

    // MARK: - Public
    // MARK: - Private
}
