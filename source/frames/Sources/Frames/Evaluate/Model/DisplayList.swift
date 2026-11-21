//
//  DisplayList.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a role draws for one frame. `size` is in output pixels and `content` is its items or, for a frame with motion
// blur, its sample lists. `colorSpace` is the space the encoder writes the frame in and `peak` the `format.peak` a
// `rec2100-pq` output is clipped to, both carried by the outermost list only, `peak` only in a `rec2100-pq` one, and nil
// in a nested one, and `compositing` the form its items' sums of colours are taken in. `seed` is the number of the output frame being drawn,
// the seed of every `grain` operation in the list, and a nested list carries its outer frame's seed.
package struct DisplayList: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let background: Color
    package let colorSpace: ColorSpace?
    package let peak: Double?
    package let compositing: Compositing
    package let seed: Int
    package let content: DisplayListContent

    // MARK: - Initializer
    package init(
        size: Size,
        background: Color,
        colorSpace: ColorSpace? = nil,
        peak: Double? = nil,
        compositing: Compositing = .encoded,
        seed: Int,
        items: [DisplayItem]
    ) {
        self.init(
            size: size,
            background: background,
            colorSpace: colorSpace,
            peak: peak,
            compositing: compositing,
            seed: seed,
            content: .items(items)
        )
    }

    package init(
        size: Size,
        background: Color,
        colorSpace: ColorSpace? = nil,
        peak: Double? = nil,
        compositing: Compositing = .encoded,
        seed: Int,
        samples: [[DisplayItem]]
    ) {
        self.init(
            size: size,
            background: background,
            colorSpace: colorSpace,
            peak: peak,
            compositing: compositing,
            seed: seed,
            content: .samples(samples)
        )
    }

    private init(
        size: Size,
        background: Color,
        colorSpace: ColorSpace?,
        peak: Double?,
        compositing: Compositing,
        seed: Int,
        content: DisplayListContent
    ) {
        self.size = size
        self.background = background
        self.colorSpace = colorSpace
        self.peak = peak
        self.compositing = compositing
        self.seed = seed
        self.content = content
    }

    // MARK: - Public
    // MARK: - Private
}
