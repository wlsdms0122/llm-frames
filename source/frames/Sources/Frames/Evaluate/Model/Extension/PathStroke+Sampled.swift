//
//  PathStroke+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A shape's stroke at one instant, nil where it is off or its width is sampled at 0, where it draws nothing. Resolve
// completed every leaf, so a leaf is always there, and its paint is its `gradient` laid over `box` or its `color`.
// Its width is drawn in output pixels at the clip's scale factor, and its dash lengths and offset are carried by the
// item's transform, so they are multiplied by `carried`, that factor over the transform's length factor. An odd dash
// list is taken twice over.
extension PathStroke {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        sampled: SampledValue,
        factor: Double,
        carried: Double,
        box: Rectangle
    ) {
        guard
            let width = sampled["width"]?.number,
            width > 0,
            let paint = Paint(sampled: sampled["gradient"], box: box) ?? sampled["color"]?.color.map(Paint.color)
        else { return nil }

        let end = { (key: String) in sampled[key]?.name.flatMap(StrokeEnd.init(rawValue:)) ?? .none }
        self.init(
            width: width * factor,
            paint: paint,
            join: sampled["join"]?.name.flatMap(StrokeJoin.init(rawValue:)) ?? .round,
            cap: sampled["cap"]?.name.flatMap(StrokeCap.init(rawValue:)) ?? .butt,
            start: end("start"),
            end: end("end"),
            dash: Self.pattern(sampled["dash"]).map { lengths in
                (lengths.count.isMultiple(of: 2) ? lengths : lengths + lengths).map { $0 * carried }
            },
            dashOffset: (sampled["dashOffset"]?.number ?? 0) * carried
        )
    }

    // MARK: - Public
    // MARK: - Private
    // Nil for no dash, and for a pattern sampled with no length, which draws the stroke whole.
    private static func pattern(_ sampled: SampledValue?) -> [Double]? {
        guard case let .list(elements) = sampled else { return nil }

        let lengths = elements.compactMap(\.number)
        return lengths.contains { $0 > 0 } ? lengths : nil
    }
}
