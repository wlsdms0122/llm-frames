//
//  MixFilterOperation.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// An audio op of a segment's filter, by the name it has in a document and in the mix plan.
package enum MixFilterOperation: Equatable, Sendable {
    case eq(bands: [MixBand])
    case compressor(MixCompressor)
    case gate(MixGate)

    // MARK: - Property
    package static let names = ["eq", "compressor", "gate"]

    package var name: String {
        switch self {
        case .eq:
            "eq"

        case .compressor:
            "compressor"

        case .gate:
            "gate"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
