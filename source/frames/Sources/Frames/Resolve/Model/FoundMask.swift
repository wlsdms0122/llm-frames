//
//  FoundMask.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A mask as resolve finds it, in the space its geometry is written in, with the geometry leaves written without
// keyframes, which a track's frame holds (FRAMES-19 Timed values).
struct FoundMask: Equatable, Sendable {
    // MARK: - Property
    let mask: ResolvedMask
    let staticLeaves: Set<MaskLeaf>

    // MARK: - Initializer
    init(
        mask: ResolvedMask,
        staticLeaves: Set<MaskLeaf> = []
    ) {
        self.mask = mask
        self.staticLeaves = staticLeaves
    }

    // MARK: - Public
    // MARK: - Private
}
