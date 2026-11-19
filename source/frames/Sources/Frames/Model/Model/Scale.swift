//
//  Scale.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A clip's scale along each of its own axes, as After Effects' Scale: a negative factor mirrors that axis about the
// anchor point. A number s is written for `[s, s]`.
struct Scale: Interpolable {
    // MARK: - Property
    static let identity = Scale(x: 1, y: 1)

    let x: Double
    let y: Double

    // The scale factor, which the lengths a clip draws the same in every direction take: the geometric mean of the
    // factors' sizes.
    var factor: Double {
        (abs(x) * abs(y)).squareRoot()
    }

    // MARK: - Initializer
    init(
        x: Double,
        y: Double
    ) {
        self.x = x
        self.y = y
    }

    init(_ factor: Double) {
        self.init(x: factor, y: factor)
    }

    // A number, or a pair of numbers.
    init?(value: JSONValue) {
        if let factor = value.numberValue {
            self.init(factor)
            return
        }

        let factors = value.arrayValue?.compactMap(\.numberValue) ?? []
        guard factors.count == 2, value.arrayValue?.count == 2 else { return nil }

        self.init(x: factors[0], y: factors[1])
    }

    // MARK: - Public
    static func interpolate(
        from start: Scale,
        to end: Scale,
        progress: Double
    ) -> Scale {
        Scale(
            x: .interpolate(from: start.x, to: end.x, progress: progress),
            y: .interpolate(from: start.y, to: end.y, progress: progress)
        )
    }

    // Both factors multiplied by one, as an animation's scale multiplies them.
    func multiplied(by factor: Double) -> Scale {
        Scale(x: x * factor, y: y * factor)
    }

    // MARK: - Private
}
