//
//  EvaluationReport.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What `evaluate` prints: the display list at sequence time `time` (as given for an image or layout, which has one),
// its frame size, and every item it draws with nested lists flattened, bottom first.
package struct EvaluationReport: Equatable, Sendable {
    // MARK: - Property
    package let time: Double
    package let size: Size
    package let items: [EvaluationItem]

    // MARK: - Initializer
    init(
        time: Double,
        size: Size,
        items: [EvaluationItem]
    ) {
        self.time = time
        self.size = size
        self.items = items
    }

    // MARK: - Public
    // MARK: - Private
}
