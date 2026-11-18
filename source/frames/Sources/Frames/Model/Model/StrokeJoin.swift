//
//  StrokeJoin.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a stroke turns at a corner of its outline, as SVG `stroke-linejoin`.
package enum StrokeJoin: String, CaseIterable, Equatable, Sendable {
    case miter
    case round
    case bevel
}
