//
//  DropShadow+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A shadow at one instant, nil where it is off. Resolve completed every leaf from the theme `shadow`.
extension DropShadow {
    // MARK: - Property
    // MARK: - Initializer
    init?(sampled: SampledValue) {
        guard let radius = sampled["radius"]?.number, let color = sampled["color"]?.color else { return nil }

        let offset = sampled["offset"]?.numbers ?? [0, 0]
        self.init(radius: radius, offset: Point(x: offset[0], y: offset[1]), color: color)
    }

    // MARK: - Public
    // MARK: - Private
}
