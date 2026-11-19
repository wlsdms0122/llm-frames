//
//  FoundMask.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A mask as resolve finds it, in the space its geometry is searched in, with the sequence times at which a text form
// gave each of its geometry leaves, which a parent's space brings back and no other value.
struct FoundMask: Equatable, Sendable {
    // MARK: - Property
    let mask: ResolvedMask
    let textTimes: [MaskLeaf: Set<Double>]

    // MARK: - Initializer
    init(
        mask: ResolvedMask,
        textTimes: [MaskLeaf: Set<Double>] = [:]
    ) {
        self.mask = mask
        self.textTimes = textTimes
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
