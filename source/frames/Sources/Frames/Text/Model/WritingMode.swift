//
//  WritingMode.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// The axis a title's lines are set along and the side they are stacked toward, as CSS `writing-mode` names them:
// horizontal lines stacked from top to bottom, or vertical lines stacked from right to left or from left to right.
//
// Text is laid out in line coordinates, x along the inline axis and y along the block axis, each the coordinate of the
// box the text fills on that axis, and `turned` takes them to the box's. Along a line is right in a horizontal mode and
// down in a vertical one, and line-under, which `lineUnder` points to on the block axis, is down in a horizontal mode
// and left in both vertical ones.
package enum WritingMode: String, CaseIterable, Equatable, Sendable {
    case horizontalTopToBottom = "horizontal-tb"
    case verticalRightToLeft = "vertical-rl"
    case verticalLeftToRight = "vertical-lr"

    // MARK: - Property
    var isVertical: Bool {
        self != .horizontalTopToBottom
    }

    // 1 where line-under is toward larger block coordinates, -1 where it is toward smaller ones.
    var lineUnder: Double {
        isVertical ? -1 : 1
    }

    // 1 where lines are stacked toward larger block coordinates, -1 where they are stacked toward smaller ones.
    private var blockEnd: Double {
        self == .verticalRightToLeft ? -1 : 1
    }

    // MARK: - Initializer
    // MARK: - Public
    // A point in line coordinates in box coordinates, or one in box coordinates in line coordinates.
    func turned(_ point: Point) -> Point {
        isVertical ? Point(x: point.y, y: point.x) : point
    }

    // A rectangle in line coordinates in box coordinates, or one in box coordinates in line coordinates: its width is
    // its inline size in line coordinates and its height its block size.
    func turned(_ rectangle: Rectangle) -> Rectangle {
        guard isVertical else { return rectangle }

        return Rectangle(x: rectangle.y, y: rectangle.x, width: rectangle.height, height: rectangle.width)
    }

    // A size, its width the inline size and its height the block size, as a box's, or a box's as that.
    func turned(_ size: Size) -> Size {
        isVertical ? Size(width: size.height, height: size.width) : size
    }

    // The block coordinate `distance` toward line-under from `baseline`, toward line-over where it is negative.
    func block(
        _ distance: Double,
        under baseline: Double
    ) -> Double {
        baseline + lineUnder * distance
    }

    // The smaller block coordinate of the stretch from `over` toward line-over of `baseline` to `under` toward
    // line-under of it.
    func blockStart(
        around baseline: Double,
        over: Double,
        under: Double
    ) -> Double {
        min(block(-over, under: baseline), block(under, under: baseline))
    }

    // The block coordinate `distance` from the block-start edge of a box `size` long on the block axis, its own
    // block-start edge at 0 when lines are stacked toward larger coordinates.
    func block(
        fromStart distance: Double,
        in size: Double
    ) -> Double {
        blockEnd > 0 ? distance : size - distance
    }

    // Of a line's `ascent` and `descent`, its extent on the side that faces block-start: its line-over side, unless
    // lines are stacked toward its line-under side.
    func startExtent(
        ascent: Double,
        descent: Double
    ) -> Double {
        blockEnd == lineUnder ? ascent : descent
    }

    // Of a line's `ascent` and `descent`, its extent on the side that faces block-end.
    func endExtent(
        ascent: Double,
        descent: Double
    ) -> Double {
        blockEnd == lineUnder ? descent : ascent
    }

    // MARK: - Private
}
