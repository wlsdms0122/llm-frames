//
//  FoundMask.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A mask as resolve finds it, in the space its geometry is searched in, with the sequence times at which a text form
// gave each of its geometry leaves, which a parent's space brings back and no other value, and the geometry leaves
// written without keyframes, which a track's frame can hold (FRAMES-19 Timed values).
struct FoundMask: Equatable, Sendable {
    // MARK: - Property
    let mask: ResolvedMask
    let textTimes: [MaskLeaf: Set<Double>]
    let staticLeaves: Set<MaskLeaf>

    // MARK: - Initializer
    init(
        mask: ResolvedMask,
        textTimes: [MaskLeaf: Set<Double>] = [:],
        staticLeaves: Set<MaskLeaf> = []
    ) {
        self.mask = mask
        self.textTimes = textTimes
        self.staticLeaves = staticLeaves
    }

    // MARK: - Public
    func isFoundByText(
        _ leaf: MaskLeaf,
        at time: Double
    ) -> Bool {
        textTimes[leaf]?.contains(time) ?? false
    }

    // MARK: - Private
}
