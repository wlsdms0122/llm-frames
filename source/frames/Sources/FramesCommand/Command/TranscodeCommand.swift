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
    let synopsis = "<in> -o <out> [--quality high|medium|low] [--max <px>] [--codec h264|hevc] [--color-space <name>]"
    let summary = "Writes a delivery file from an image, audio or video file, in the format the output's extension "
        + "names and at a quality level. Metadata is not copied, and rotation is applied to the pixels."

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
