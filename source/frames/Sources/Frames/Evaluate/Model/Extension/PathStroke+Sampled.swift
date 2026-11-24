//
//  PathStroke+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A shape's stroke at one instant, nil where it is off, and where its width is sampled at 0, where it draws nothing,
// outside a sample of a frame with motion blur. In such a sample a stroke that is on is there at any width, 0 included,
// and its dash at any lengths, all 0 included, since whether they are there is decided at T (FRAMES-29). Resolve
// completed every leaf, so a leaf is always there, each end its `shape` and `scale`, and its paint is its `gradient`
// laid over `box` or its `color`. Its width is drawn in output pixels at the clip's scale factor, and its dash lengths
// and offset are carried by the item's transform, so they are multiplied by `carried`, that factor over the
// transform's length factor. An odd dash list is taken twice over.
extension PathStroke {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        sampled: SampledValue,
        factor: Double,
        carried: Double,
        box: Rectangle,
        isSample: Bool
    ) {
        guard
            let width = sampled["width"]?.number,
            width > 0 || isSample,
            let paint = Paint(sampled: sampled["gradient"], box: box) ?? sampled["color"]?.color.map(Paint.color)
        else { return nil }

        let end = { (key: String) in
            StrokeEnd(
                shape: sampled[key]?["shape"]?.name.flatMap(StrokeEndShape.init(rawValue:)) ?? .none,
                scale: sampled[key]?["scale"]?.number ?? 1
            )
        }
        self.init(
            width: width * factor,
            paint: paint,
            align: sampled["align"]?.name.flatMap(StrokeAlign.init(rawValue:)) ?? .center,
            join: sampled["join"]?.name.flatMap(StrokeJoin.init(rawValue:)) ?? .round,
            cap: sampled["cap"]?.name.flatMap(StrokeCap.init(rawValue:)) ?? .butt,
            start: end("start"),
            end: end("end"),
            dash: Self.pattern(sampled["dash"], isSample: isSample).map { lengths in
                (lengths.count.isMultiple(of: 2) ? lengths : lengths + lengths).map { $0 * carried }
            },
            dashOffset: (sampled["dashOffset"]?.number ?? 0) * carried
        )
    }

    // MARK: - Public
    // MARK: - Private
    // Nil for no dash, and outside a sample for a pattern sampled with no length, which draws the stroke whole.
    private static func pattern(
        _ sampled: SampledValue?,
        isSample: Bool
    ) -> [Double]? {
        guard case let .list(elements) = sampled else { return nil }

        let lengths = elements.compactMap(\.number)
        return lengths.contains { $0 > 0 } || isSample ? lengths : nil
    }
}
