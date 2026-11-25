//
//  RunStage.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// A stage of a run of `render`, by the work it covers (FRAMES-23 Runs). The cases are in the order a report gives
// them, and the first seven run on the render's own thread, `decode` and `workingConversion` also on the threads a
// decoder reads ahead on.
package enum RunStage: String, CaseIterable, Sendable {
    case resolve
    case check
    case evaluate
    case mix
    case decode
    case workingConversion
    case draw
    case outputConversion
    case encode

    // MARK: - Property
    // Whether the render's own thread runs the stage, one at a time with the others that do.
    package var isOnRenderThread: Bool {
        switch self {
        case .resolve, .check, .evaluate, .mix, .decode, .workingConversion, .draw:
            true

        case .outputConversion, .encode:
            false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
