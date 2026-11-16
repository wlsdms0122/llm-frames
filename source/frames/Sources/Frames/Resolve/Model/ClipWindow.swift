//
//  ClipWindow.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A clip's `at`: a window `[start, end]` of two instants, or a single start followed by the clip's natural length.
enum ClipWindow: Equatable, Sendable {
    case range(start: Double, end: Double)
    case start(Double)
}
