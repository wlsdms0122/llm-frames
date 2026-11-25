//
//  Paint+Sampled.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A shape's paint at one instant, from a sampled `fill` or stroke `paint` form, nil where it is off. A gradient's
// points are fractions of the shape's box as it is placed at that instant, `[x + u × w, y + v × h]`, and a radial
// radius is a fraction of the distance from its centre to the box's farthest corner, so the gradient follows the box.
// Each sampled offset, already clamped to 0 to 1, is raised to the one before it.
extension Paint {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        sampled: SampledValue?,
        box: Rectangle
    ) {
        guard case let .form(name, body) = sampled else { return nil }

        let point = { (key: String) -> Point? in
            body[key]?.numbers.map { fractions in
                Point(x: box.x + fractions[0] * box.width, y: box.y + fractions[1] * box.height)
            }
        }
        let shape: GradientShape
        switch name {
        case ValueStructure.colorForm:
            guard let color = body.color else { return nil }

            self = .color(color)
            return

        case "kind:linear":
            guard let from = point("from"), let to = point("to") else { return nil }

            shape = .linear(from: from, to: to)

        case "kind:radial":
            guard let center = point("center") else { return nil }

            let corners = [(box.x, box.y), (box.maxX, box.y), (box.x, box.maxY), (box.maxX, box.maxY)]
            let farthest = corners.map { x, y in
                ((x - center.x) * (x - center.x) + (y - center.y) * (y - center.y)).squareRoot()
            }.max() ?? 0
            shape = .radial(center: center, radius: (body["radius"]?.number ?? 1) * farthest)

        default:
            return nil
        }

        guard case let .list(elements) = body["stops"] else { return nil }

        var least = 0.0
        let stops = elements.compactMap { element -> GradientStop? in
            guard
                case let .list(pair) = element,
                pair.count == 2,
                let offset = pair[0].number,
                let color = pair[1].color
            else { return nil }

            least = max(least, offset)
            return GradientStop(offset: least, color: color)
        }
        self = .gradient(Gradient(shape: shape, stops: stops))
    }

    // MARK: - Public
    // MARK: - Private
}
