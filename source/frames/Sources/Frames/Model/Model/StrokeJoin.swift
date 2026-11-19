//
//  StrokeJoin.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

package enum StrokeJoin: String, CaseIterable, Equatable, Sendable {
    case miter
    case round
    case bevel

    // MARK: - Property
    // A miter longer than this many stroke widths is drawn as a bevel.
    package static let miterLimit = 4.0

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
