//
//  BitDepth.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The form of each component of a bitmap: an eight or sixteen bit unsigned integer, or a sixteen bit IEEE 754 half
// float.
package enum BitDepth: Equatable, Sendable {
    case eight
    case sixteen
    case halfFloat

    // MARK: - Property
    package var bitsPerComponent: Int {
        switch self {
        case .eight:
            8

        case .sixteen, .halfFloat:
            16
        }
    }

    // MARK: - Initializer
    // The depth that holds components of `bitsPerComponent` bits, as media gives them, without loss.
    package init(holding bitsPerComponent: Int) {
        self = bitsPerComponent > 8 ? .sixteen : .eight
    }

    // MARK: - Public
    // MARK: - Private
}
