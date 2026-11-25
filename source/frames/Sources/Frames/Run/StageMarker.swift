//
//  StageMarker.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Marks the work of a stage where a profiler shows it: on macOS an `os_signpost` interval named by the stage
// (FRAMES-23 Runs).
package protocol StageMarker: Sendable {
    func interval<Result>(
        of stage: RunStage,
        _ work: () throws -> Result
    ) rethrows -> Result
}
