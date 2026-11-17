//
//  TimeSelection.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The media times an analysis command reads: the start, one time (`--at`), or a range.
package enum TimeSelection: Equatable, Sendable {
    case start
    case at(Double)
    case range(FrameRange)
}
