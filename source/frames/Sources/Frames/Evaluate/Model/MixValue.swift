//
//  MixValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A number of a segment's audio filter: one that holds over the segment, or one that moves, as an envelope of points
// in sequence time joined in straight lines. A moving `frequency` has its points sampled in log space, so the straight
// lines between them stand in for a geometric sweep.
package enum MixValue: Equatable, Sendable {
    case constant(Double)
    case envelope([EnvelopePoint])

    // MARK: - Property
    package var isMoving: Bool {
        switch self {
        case .constant:
            false

        case let .envelope(points):
            points.contains { $0.value != points.first?.value }
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
