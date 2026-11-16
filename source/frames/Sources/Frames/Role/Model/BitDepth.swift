//
//  BitDepth.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The bits of each component of a bitmap.
package enum BitDepth: Equatable, Sendable {
    case eight
    case sixteen

    // MARK: - Property
    package var bitsPerComponent: Int {
        switch self {
        case .eight:
            8

        case .sixteen:
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
