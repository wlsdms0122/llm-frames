//
//  ConversionDevice.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// The processor a decoder took a medium's pictures to working values on, or an encoder a file's frames to the output's
// values on, as a run's report names it (FRAMES-23 Runs).
package enum ConversionDevice: Hashable, Sendable {
    case cpu
    case gpu

    // MARK: - Property
    package var name: String {
        switch self {
        case .cpu:
            "cpu"

        case .gpu:
            "gpu"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
