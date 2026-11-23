//
//  CubicCoordinate.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// One coordinate of a cubic Bézier curve as its parameter t runs from 0 to 1, by the coordinate of its four control
// points in order: its start, its two control points and its end.
struct CubicCoordinate: Equatable, Sendable {
    // MARK: - Property
    let start: Double
    let first: Double
    let second: Double
    let end: Double

    // The parameters where the coordinate's derivative, 3 times a t² + b t + c, is 0, and nil where it is 0
    // everywhere, a coordinate that holds still. A coefficient that small beside the largest counts as 0, and a
    // discriminant that small below 0 as a double root, which rounding moves either way.
    var turns: [Double]? {
        let a = -start + 3 * first - 3 * second + end
        let b = 2 * (start - 2 * first + second)
        let c = first - start
        let scale = max(abs(a), abs(b), abs(c))
        guard scale > 0 else { return nil }
        guard abs(a) > Self.precision * scale else { return abs(b) > Self.precision * scale ? [-c / b] : [] }

        let discriminant = b * b - 4 * a * c
        guard discriminant >= -Self.precision * b * b else { return [] }

        let root = max(discriminant, 0).squareRoot()
        return [(-b + root) / (2 * a), (-b - root) / (2 * a)]
    }

    private static let precision = 1e-12

    // MARK: - Initializer
    init(
        _ start: Double,
        _ first: Double,
        _ second: Double,
        _ end: Double
    ) {
        self.start = start
        self.first = first
        self.second = second
        self.end = end
    }

    // MARK: - Public
    func value(at t: Double) -> Double {
        let rest = 1 - t
        return rest * rest * rest * start + 3 * rest * rest * t * first + 3 * rest * t * t * second + t * t * t * end
    }

    // MARK: - Private
}
