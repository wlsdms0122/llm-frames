//
//  StageSignposter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import Frames
import os

// Marks each stage's work as an `os_signpost` interval named by the stage, in the subsystem `frames` and the category
// `stages`, so Instruments shows a run's stages by name (FRAMES-23 Runs).
package struct StageSignposter: StageMarker {
    // MARK: - Property
    private static let signposter = OSSignposter(subsystem: "frames", category: "stages")

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func interval<Result>(
        of stage: RunStage,
        _ work: () throws -> Result
    ) rethrows -> Result {
        let signposter = Self.signposter
        let state = signposter.beginInterval(Self.name(of: stage), id: signposter.makeSignpostID())
        defer { signposter.endInterval(Self.name(of: stage), state) }

        return try work()
    }

    // MARK: - Private
    // A signpost's name is a static string, so each stage's is written out.
    private static func name(of stage: RunStage) -> StaticString {
        switch stage {
        case .resolve:
            "resolve"

        case .check:
            "check"

        case .evaluate:
            "evaluate"

        case .mix:
            "mix"

        case .decode:
            "decode"

        case .workingConversion:
            "workingConversion"

        case .draw:
            "draw"

        case .outputConversion:
            "outputConversion"

        case .encode:
            "encode"
        }
    }
}
