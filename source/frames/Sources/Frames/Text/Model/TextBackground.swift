//
//  TextBackground.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A box behind the text. `padding` is its room above and below the text (`height`) and on its left and right
// (`width`), in output pixels, as is `radius`.
struct TextBackground: Equatable, Sendable {
    // MARK: - Property
    let color: Color
    let padding: Size
    let radius: Double

    // MARK: - Initializer
    init(
        color: Color,
        padding: Size,
        radius: Double
    ) {
        self.color = color
        self.padding = padding
        self.radius = radius
    }

    // MARK: - Public
    // MARK: - Private
}
