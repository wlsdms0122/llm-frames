//
//  StrokeCap.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a stroke ends at an end of an open outline or a trimmed piece.
package enum StrokeCap: String, CaseIterable, Equatable, Sendable {
    case butt
    case round
    case square
}
