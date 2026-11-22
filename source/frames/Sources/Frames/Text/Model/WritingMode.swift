//
//  WritingMode.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// The axis a title's lines are set along and the side they are stacked toward, as CSS `writing-mode` names them:
// horizontal lines stacked from top to bottom, or vertical lines stacked from right to left or from left to right.
package enum WritingMode: String, CaseIterable, Equatable, Sendable {
    case horizontalTopToBottom = "horizontal-tb"
    case verticalRightToLeft = "vertical-rl"
    case verticalLeftToRight = "vertical-lr"

    // MARK: - Property
    var isVertical: Bool {
        self != .horizontalTopToBottom
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
