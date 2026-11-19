//
//  PathStroke+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A shape's stroke at one instant, nil where it is off or its width is sampled at 0, where it draws nothing. Resolve
// completed every leaf, so a leaf is always there. Its width is drawn in output pixels at the clip's scale factor.
extension PathStroke {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        sampled: SampledValue,
        factor: Double
    ) {
        guard let width = sampled["width"]?.number, width > 0, let color = sampled["color"]?.color else { return nil }

        let end = { (key: String) in sampled[key]?.name.flatMap(StrokeEnd.init(rawValue:)) ?? .none }
        self.init(
            width: width * factor,
            color: color,
            join: sampled["join"]?.name.flatMap(StrokeJoin.init(rawValue:)) ?? .round,
            cap: sampled["cap"]?.name.flatMap(StrokeCap.init(rawValue:)) ?? .butt,
            start: end("start"),
            end: end("end")
        )
    }

    // MARK: - Public
    // MARK: - Private
}
