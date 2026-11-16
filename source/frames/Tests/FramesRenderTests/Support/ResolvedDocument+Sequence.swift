//
//  ResolvedDocument+Sequence.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

extension ResolvedDocument {
    // MARK: - Property
    var sequence: ResolvedSequence? {
        guard case let .sequence(sequence) = self else { return nil }

        return sequence
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
