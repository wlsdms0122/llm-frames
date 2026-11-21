//
//  EvaluationReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `evaluate` prints: the display list at sequence time `time`, its frame size, every item it draws with nested
// lists flattened, bottom first, and the text of every title drawn then, in the order of its first item.
package struct EvaluationReport: Equatable, Sendable {
    // MARK: - Property
    package let time: Double
    package let size: Size
    package let items: [EvaluationItem]
    package let texts: [EvaluationText]

    // MARK: - Initializer
    init(
        time: Double,
        size: Size,
        items: [EvaluationItem],
        texts: [EvaluationText]
    ) {
        self.time = time
        self.size = size
        self.items = items
        self.texts = texts
    }

    // MARK: - Public
    // MARK: - Private
}
