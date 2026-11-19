//
//  DropShadow+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A shadow at one instant, nil where it is off. Resolve completed every leaf from the theme `shadow`. Its radius is
// drawn in output pixels at the clip's scale factor, and its offset is carried by the item's transform, so it is
// multiplied by `carried`, that factor over the transform's length factor.
extension DropShadow {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        sampled: SampledValue,
        factor: Double,
        carried: Double
    ) {
        guard let radius = sampled["radius"]?.number, let color = sampled["color"]?.color else { return nil }

        let offset = sampled["offset"]?.numbers ?? [0, 0]
        self.init(
            radius: radius * factor,
            offset: Point(x: offset[0] * carried, y: offset[1] * carried),
            color: color
        )
    }

    // MARK: - Public
    // MARK: - Private
}
