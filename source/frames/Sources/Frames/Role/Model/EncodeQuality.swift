//
//  EncodeQuality.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// How hard an encoder shrinks a file it compresses: a JPEG or HEIC at `imageQuality`, from 0 to 1, AAC sound at
// `soundBitRate` bits a second per channel, and video at a level each encoder maps onto its own codec settings.
package enum EncodeQuality: String, CaseIterable, Sendable {
    case high
    case medium
    case low

    // MARK: - Property
    package var imageQuality: Double {
        switch self {
        case .high:
            0.9

        case .medium:
            0.75

        case .low:
            0.55
        }
    }

    package var soundBitRate: Int {
        switch self {
        case .high:
            96_000

        case .medium:
            64_000

        case .low:
            32_000
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
