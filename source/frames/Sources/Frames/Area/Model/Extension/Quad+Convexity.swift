//
//  Quad+Convexity.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

extension Quad {
    // MARK: - Property
    // The four turns z_k = (x_{k+1} - x_k) (y_{k+2} - y_{k+1}) - (y_{k+1} - y_k) (x_{k+2} - x_{k+1}), k = 0 to 3 with
    // indices taken modulo 4 (FRAMES-27). Each product is rounded before the subtraction, with no fused multiply-add, so
    // the test decides alike in every implementation for points written in the document.
    var turns: [Double] {
        let corners = corners

        return (0 ..< 4).map { index in
            let first = corners[index]
            let second = corners[(index + 1) % 4]
            let third = corners[(index + 2) % 4]
            let product = (second.x - first.x) * (third.y - second.y)
            let other = (second.y - first.y) * (third.x - second.x)

            return product - other
        }
    }

    // The sign the four turns share, nil when they do not share one: a turn of 0 is neither above nor below 0, so a
    // quad with three corners on one line or two on one point has none.
    package var orientation: Orientation? {
        let turns = turns
        if turns.allSatisfy({ $0 > 0 }) {
            return .clockwise
        }
        if turns.allSatisfy({ $0 < 0 }) {
            return .counterclockwise
        }

        return nil
    }

    package var isStrictlyConvex: Bool {
        orientation != nil
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
