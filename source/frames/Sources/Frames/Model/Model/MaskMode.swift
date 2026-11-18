//
//  MaskMode.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a mask combines with the masks before it on one clip.
package enum MaskMode: String, CaseIterable, Equatable, Sendable {
    case add
    case subtract
    case intersect

    // MARK: - Property
    // The result before the first mask, when this is the first mask's mode: nothing for `add`, so the first mask is
    // what shows, and everything for `subtract` and `intersect`, which cut from the whole picture.
    package var startValue: Double {
        self == .add ? 0 : 1
    }

    // MARK: - Initializer
    // MARK: - Public
    // The result once a mask of value `mask` combines with the result `result` of the masks before it.
    package func combine(
        _ result: Double,
        with mask: Double
    ) -> Double {
        switch self {
        case .add:
            result + mask - result * mask

        case .subtract:
            result * (1 - mask)

        case .intersect:
            result * mask
        }
    }

    // MARK: - Private
}
