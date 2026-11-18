//
//  DisplayList.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a role draws for one frame. `size` is in output pixels and `items` are bottom first. `seed` is the number of
// the output frame being drawn, the seed of every `grain` operation in the list, and a nested list carries its outer
// frame's seed.
package struct DisplayList: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let background: Color
    package let seed: Int
    package let items: [DisplayItem]

    // MARK: - Initializer
    package init(
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
