//
//  DisplayList.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a role draws for one frame. `size` is in output pixels and `items` are bottom first. A frame with motion blur
// holds `samples` in place of `items`, its sample lists in order, each a whole list of items of the frame at one instant
// of its exposure, and the frame is their mean. Only the outermost list holds samples, and it then has no `items`.
// `colorSpace` is the space the encoder writes the frame in and `peak` the `format.peak` a `rec2100-pq` output is
// clipped to, both carried by the outermost list only, `peak` only in a `rec2100-pq` one, and nil in a nested one, and
// `compositing` the form its items' sums of colours are taken in. `seed` is the number of the output frame being drawn,
// the seed of every `grain` operation in the list, and a nested list carries its outer frame's seed.
package struct DisplayList: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let background: Color
    package let colorSpace: ColorSpace?
    package let peak: Double?
    package let compositing: Compositing
    package let seed: Int
    package let items: [DisplayItem]
    package let samples: [[DisplayItem]]?

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
            items: items,
            samples: nil
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
            items: [],
            samples: samples
        )
    }

    private init(
        size: Size,
        background: Color,
        colorSpace: ColorSpace?,
        peak: Double?,
        compositing: Compositing,
        seed: Int,
        items: [DisplayItem],
        samples: [[DisplayItem]]?
    ) {
        self.size = size
        self.background = background
        self.colorSpace = colorSpace
        self.peak = peak
        self.compositing = compositing
        self.seed = seed
        self.items = items
        self.samples = samples
    }

    // MARK: - Public
    // MARK: - Private
}
