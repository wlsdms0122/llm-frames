//
//  ArrowItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A straight arrow from `tail` to the tip of its head at `head`, its line `width` wide and its head `headSize` long
// and wide.
struct ArrowItem: Equatable, Sendable {
    // MARK: - Property
    let tail: Point
    let head: Point
    let width: Double
    let headSize: Double
    let color: Color

    // MARK: - Initializer
    init(
        tail: Point,
        head: Point,
        width: Double,
        headSize: Double,
        color: Color
    ) {
        self.tail = tail
        self.head = head
        self.width = width
        self.headSize = headSize
        self.color = color
    }

    // The arrow found pointing at an area, its tip as the head.
    init(
        arrow: Arrow,
        width: Double,
        headSize: Double,
        color: Color
    ) {
        self.init(tail: arrow.tail, head: arrow.tip, width: width, headSize: headSize, color: color)
    }

    // MARK: - Public
    // MARK: - Private
}
