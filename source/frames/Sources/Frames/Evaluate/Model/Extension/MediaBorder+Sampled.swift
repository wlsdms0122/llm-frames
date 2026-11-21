//
//  MediaBorder+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A box's border at one instant, nil where it is off, and where its width is sampled at 0, where it draws nothing,
// outside a sample of a frame with motion blur. In such a sample a border that is on is there at any width, 0 included,
// since whether it is there is decided at T (FRAMES-29). Resolve completed every leaf from the theme `border`. Its width
// is drawn in output pixels at the clip's scale factor.
extension MediaBorder {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        sampled: SampledValue,
        factor: Double,
        isSample: Bool
    ) {
        guard
            let width = sampled["width"]?.number,
            width > 0 || isSample,
            let color = sampled["color"]?.color
        else { return nil }

        self.init(width: width * factor, color: color)
    }

    // MARK: - Public
    // MARK: - Private
}
