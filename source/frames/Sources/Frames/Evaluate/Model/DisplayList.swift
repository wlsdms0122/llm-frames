//
//  DisplayList.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a role draws for one frame: the frame's size in output pixels, its background, and its items bottom first,
// every value sampled. `seed` is the number of the output frame being drawn, the seed of every `grain` operation in
// the list and in the lists nested in it, so a nested list carries its outer frame's seed.
struct DisplayList: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let background: Color
    let seed: Int
    let items: [DisplayItem]

    // MARK: - Initializer
    init(
        size: Size,
        background: Color,
        seed: Int,
        items: [DisplayItem]
    ) {
        self.size = size
        self.background = background
        self.seed = seed
        self.items = items
    }

    // MARK: - Public
    // MARK: - Private
}
