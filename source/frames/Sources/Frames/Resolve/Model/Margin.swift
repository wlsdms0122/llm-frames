//
//  Margin.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The room a content-fit frame leaves round its content on each side, in whole output pixels.
struct Margin: Equatable, Sendable {
    // MARK: - Property
    static let zero = Margin(top: 0, right: 0, bottom: 0, left: 0)

    let top: Double
    let right: Double
    let bottom: Double
    let left: Double

    // MARK: - Initializer
    init(
        top: Double,
        right: Double,
        bottom: Double,
        left: Double
    ) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    // Reads `n` (every side), `[v, h]` (top and bottom, left and right) or `[t, r, b, l]`, in the order CSS writes
    // them. The key tables have checked the form.
    init(value: JSONValue) {
        let sides = value.numberValue.map { [$0] } ?? value.arrayValue?.compactMap(\.numberValue) ?? []

        switch sides.count {
        case 1:
            self.init(top: sides[0], right: sides[0], bottom: sides[0], left: sides[0])

        case 2:
            self.init(top: sides[0], right: sides[1], bottom: sides[0], left: sides[1])

        case 4:
            self.init(top: sides[0], right: sides[1], bottom: sides[2], left: sides[3])

        default:
            self = .zero
        }
    }

    // MARK: - Public
    // MARK: - Private
}
