//
//  NamedPoint.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The point of an area a placement name names, `{area, point}` (FRAMES-2): `top-left` its top left corner, `center`
// its centre.
struct NamedPoint: Equatable, Sendable {
    // MARK: - Property
    let area: Rectangle
    let name: String

    // MARK: - Initializer
    init(
        area: Rectangle,
        name: String
    ) {
        self.area = area
        self.name = name
    }

    // MARK: - Public
    // The point the name names on the area grown on every side by `length`.
    func point(grownBy length: Double) -> Point {
        area.grown(by: length).point(named: name)
    }

    // MARK: - Private
}
