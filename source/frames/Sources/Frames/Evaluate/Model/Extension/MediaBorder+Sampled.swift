//
//  MediaBorder+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A box's border at one instant, nil where it is off or its width is sampled at 0, where it draws nothing. Resolve
// completed every leaf from the theme `border`.
extension MediaBorder {
    // MARK: - Property
    // MARK: - Initializer
    init?(sampled: SampledValue) {
        guard let width = sampled["width"]?.number, width > 0, let color = sampled["color"]?.color else { return nil }

        self.init(width: width, color: color)
    }

    // MARK: - Public
    // MARK: - Private
}
