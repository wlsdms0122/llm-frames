//
//  EvaluationItem.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// One item `evaluate` reports: the clip that drew it, nil for the background and a transition cover, what it draws,
// the axis-aligned box of what it covers of the output, nil when it covers nothing, its opacity times that of every
// picture holding it, the map from its own coordinates to output pixels with the corner pins that carry it left out,
// its extent in its own coordinates before its reveal, its masks and the pictures holding it cut it, those corner pins,
// innermost first, nil on an item no corner pin carries, and the characters it reports, nil on an item that reports
// none.
package struct EvaluationItem: Equatable, Sendable {
    // MARK: - Property
    package let origin: ItemOrigin?
    package let item: ItemKind
    package let bounds: Rectangle?
    package let opacity: Double
    package let transform: AffineTransform
    package let rect: Rectangle
    package let cornerPins: [EvaluationCornerPin]?
    package let characters: [EvaluationCharacter]?

    // MARK: - Initializer
    init(
        origin: ItemOrigin?,
        item: ItemKind,
        bounds: Rectangle?,
        opacity: Double,
        transform: AffineTransform,
        rect: Rectangle,
        cornerPins: [EvaluationCornerPin]? = nil,
        characters: [EvaluationCharacter]? = nil
    ) {
        self.origin = origin
        self.item = item
        self.bounds = bounds
        self.opacity = opacity
        self.transform = transform
        self.rect = rect
        self.cornerPins = cornerPins
        self.characters = characters
    }

    init(
        _ item: FlattenedItem,
        characters: [EvaluationCharacter]? = nil
    ) {
        self.init(
            origin: item.origin,
            item: item.item,
            bounds: item.coverage.bounds,
            opacity: item.opacity,
            transform: item.transform,
            rect: item.rect,
            cornerPins: item.cornerPins.isEmpty ? nil : item.cornerPins,
            characters: characters
        )
    }

    // MARK: - Public
    // MARK: - Private
}
