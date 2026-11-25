//
//  ProgressWriter.swift
//  FramesCommand
//
//  Created by JSilver on 11/25/26.
//

import Frames

// Writes a run's progress on standard error in its format: for the first frame drawn a second or more after the last
// line, or after the run began, and for the last frame always (FRAMES-23 Runs). Used from one thread.
final class ProgressWriter {
    // MARK: - Property
    private static let interval: Double = 1

    private let format: ProgressFormat
    private let output: CommandOutput
    private var lastLine: Double = 0

    // MARK: - Initializer
    init(
        format: ProgressFormat,
        output: CommandOutput
    ) {
        self.format = format
        self.output = output
    }

    // MARK: - Public
    func write(_ progress: RunProgress) {
        guard progress.frame == progress.frames || progress.seconds - lastLine >= Self.interval else { return }
        lastLine = progress.seconds

        switch format {
        case .text:
            output.writeError(progress.text + "\n")

        case .json:
            output.writeError(JSONWriter().writeLine(progress.machineOutput))

        case .none:
            break
        }
    }

    // MARK: - Private
}
