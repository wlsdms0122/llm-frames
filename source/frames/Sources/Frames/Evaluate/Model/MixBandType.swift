//
//  MixBandType.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The biquads of the RBJ Audio EQ Cookbook an `eq` band can be, by their names in the mix plan.
package enum MixBandType: String, CaseIterable, Sendable {
    case lowShelf
    case highShelf
    case peak
    case lowPass
    case highPass

    // MARK: - Property
    package var takesGain: Bool {
        switch self {
        case .lowShelf, .highShelf, .peak:
            true

        case .lowPass, .highPass:
            false
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
