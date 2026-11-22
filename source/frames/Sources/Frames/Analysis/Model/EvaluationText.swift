//
//  EvaluationText.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The text of one title drawn at the time, as `evaluate` reports it: the title's place and `id`, its text, the
// paragraph direction it was laid out in, its text box's size then, its box then in its text box, the map from its
// text box to output pixels without any unit's motion with the corner pins that carry it left out, those corner pins
// as its item reports them, and its lines and words in reading order.
package struct EvaluationText: Equatable, Sendable {
    // MARK: - Property
    package let place: String
    package let id: String?
    package let text: String
    package let direction: TextDirection
    package let size: Size
    package let box: Rectangle
    package let transform: AffineTransform
    package let cornerPins: [EvaluationCornerPin]?
    package let lines: [EvaluationLine]
    package let words: [EvaluationWord]

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        text: String,
        direction: TextDirection,
        size: Size,
        box: Rectangle,
        transform: AffineTransform,
        cornerPins: [EvaluationCornerPin]? = nil,
        lines: [EvaluationLine],
        words: [EvaluationWord]
    ) {
        self.place = place
        self.id = id
        self.text = text
        self.direction = direction
        self.size = size
        self.box = box
        self.transform = transform
        self.cornerPins = cornerPins
        self.lines = lines
        self.words = words
    }

    // MARK: - Public
    // MARK: - Private
}
