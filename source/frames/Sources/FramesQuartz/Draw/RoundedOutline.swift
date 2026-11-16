//
//  RoundedOutline.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import Frames

// The outline of a rectangle with circular corners in y-down coordinates, from the start of its top edge after the top
// left corner's arc, clockwise. A radius past half the shorter side is held at it.
struct RoundedOutline {
    // MARK: - Property
    private let rectangle: CGRect
    private let radius: CGFloat

    // The whole outline as one closed path.
    var path: CGPath {
        path(trim: 1)
    }

    // MARK: - Initializer
    init(
        rectangle: Rectangle,
        radius: Double
    ) {
        let frame = CGRect(rectangle)

        self.rectangle = frame
        self.radius = max(0, min(radius, frame.width / 2, frame.height / 2))
    }

    init(_ rounded: RoundedRectangle) {
        self.init(rectangle: rounded.rectangle, radius: rounded.radius)
    }

    // MARK: - Public
    // The outline as far as `trim` of its length, closed when it reaches the end.
    func path(trim: Double) -> CGPath {
        let path = CGMutablePath()
        let segments = self.segments
        let length = segments.map(\.length).reduce(0, +)
        guard trim > 0, length > 0 else { return path }

        var left = CGFloat(min(trim, 1)) * length
        path.move(to: CGPoint(x: rectangle.minX + radius, y: rectangle.minY))
        for segment in segments where left > 0 {
            let part = min(1, segment.length > 0 ? left / segment.length : 1)
            append(segment, part: part, to: path)
            left -= segment.length
        }
        if trim >= 1 { path.closeSubpath() }

        return path
    }

    // MARK: - Private
    // Top edge, top right corner, right edge and so on round to the top left corner. In y-down coordinates a growing
    // angle turns clockwise.
    private var segments: [OutlineSegment] {
        let minX = rectangle.minX
        let minY = rectangle.minY
        let maxX = rectangle.maxX
        let maxY = rectangle.maxY

        return [
            .line(from: CGPoint(x: minX + radius, y: minY), to: CGPoint(x: maxX - radius, y: minY)),
            .arc(center: CGPoint(x: maxX - radius, y: minY + radius), start: -.pi / 2, radius: radius),
            .line(from: CGPoint(x: maxX, y: minY + radius), to: CGPoint(x: maxX, y: maxY - radius)),
            .arc(center: CGPoint(x: maxX - radius, y: maxY - radius), start: 0, radius: radius),
            .line(from: CGPoint(x: maxX - radius, y: maxY), to: CGPoint(x: minX + radius, y: maxY)),
            .arc(center: CGPoint(x: minX + radius, y: maxY - radius), start: .pi / 2, radius: radius),
            .line(from: CGPoint(x: minX, y: maxY - radius), to: CGPoint(x: minX, y: minY + radius)),
            .arc(center: CGPoint(x: minX + radius, y: minY + radius), start: .pi, radius: radius)
        ]
    }

    private func append(
        _ segment: OutlineSegment,
        part: CGFloat,
        to path: CGMutablePath
    ) {
        switch segment {
        case let .line(from, to):
            path.addLine(to: CGPoint(x: from.x + (to.x - from.x) * part, y: from.y + (to.y - from.y) * part))

        case let .arc(center, start, radius):
            guard radius > 0 else { return }

            path.addArc(
                center: center,
                radius: radius,
                startAngle: start,
                endAngle: start + .pi / 2 * part,
                clockwise: false
            )
        }
    }
}
