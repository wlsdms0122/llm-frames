//
//  FilterChain.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Frames

// Applies a picture's filter operations in order to an image in the working space.
struct FilterChain: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // `seed` is the display list's, which every `grain` operation draws its noise from.
    func apply(
        _ operations: [ResolvedFilterOperation],
        to image: CIImage,
        seed: Int
    ) throws -> CIImage {
        image
    }

    // MARK: - Private
}
