//
//  TimeSelection.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// The media times an analysis command reads: the start, one time (`--at`), or a range from `from` (the start when
// nil) to `to` (the end when nil) every `step` seconds.
package enum TimeSelection: Equatable, Sendable {
    case start
    case at(Double)
    case range(from: Double?, to: Double?, step: Double)
}
