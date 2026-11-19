//
//  Gradient.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A linear or a radial gradient in an item's own coordinates, carried by its transform with its geometry, its stops'
// offsets from 0 to 1 and in order.
package struct Gradient: Equatable, Sendable {
    // MARK: - Property
    package let shape: GradientShape
    package let stops: [GradientStop]

    // A linear gradient whose ends are one point, or a radial one of radius 0, paints its last stop's colour.
    package var isDegenerate: Bool {
        switch shape {
        case let .linear(from, to):
            from == to

        case let .radial(_, radius):
            radius <= 0
        }
    }

    // MARK: - Initializer
    package init(
        shape: GradientShape,
        stops: [GradientStop]
    ) {
        self.shape = shape
        self.stops = stops
    }

    // MARK: - Public
    // The gradient's position at a point: its projection onto the line from `from` to `to` in lengths of that line,
    // or its distance from the centre in radii. Nil where the gradient is degenerate.
    package func position(of point: Point) -> Double? {
        guard !isDegenerate else { return nil }

        switch shape {
        case let .linear(from, to):
            let axis = Point(x: to.x - from.x, y: to.y - from.y)
            return ((point.x - from.x) * axis.x + (point.y - from.y) * axis.y) / (axis.x * axis.x + axis.y * axis.y)

        case let .radial(center, radius):
            return ((point.x - center.x) * (point.x - center.x) + (point.y - center.y) * (point.y - center.y))
                .squareRoot() / radius
        }
    }

    // Straight red, green, blue and alpha at a position: the first stop's at or below its offset, the last stop's at
    // or past its offset, and between two neighbouring stops their colours interpolated with premultiplied alpha, so a
    // transparent stop adds no colour of its own. Where two stops share an offset the later one's colour starts there.
    package func channels(at position: Double) -> [Double] {
        guard let first = stops.first, let last = stops.last else { return [0, 0, 0, 0] }
        guard position > first.offset else { return first.color.channels }
        guard let index = stops.indices.dropFirst().first(where: { position < stops[$0].offset }) else {
            return last.color.channels
        }

        let lower = stops[index - 1]
        let upper = stops[index]
        let progress = (position - lower.offset) / (upper.offset - lower.offset)
        let mixed = zip(premultiplied(lower.color), premultiplied(upper.color)).map { start, end in
            start + (end - start) * progress
        }
        let alpha = mixed[3]
        guard alpha > 0 else { return [0, 0, 0, 0] }

        return [mixed[0] / alpha, mixed[1] / alpha, mixed[2] / alpha, alpha]
    }

    // MARK: - Private
    private func premultiplied(_ color: Color) -> [Double] {
        let channels = color.channels
        return [channels[0] * channels[3], channels[1] * channels[3], channels[2] * channels[3], channels[3]]
    }
}
