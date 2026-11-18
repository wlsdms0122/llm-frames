//
//  AffineTransform+GeometryPlacement.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The own transform of a shape placed by its geometry. `box` is its geometry's box as written, before its outset, in
// the space it is written in.
extension AffineTransform {
    // MARK: - Property
    // MARK: - Initializer
    init(
        placing box: Rectangle,
        anchor: Point?,
        position: Point?,
        scale: Double,
        rotation: Double,
        moved: Point = Point(x: 0, y: 0)
    ) {
        let anchor = anchor ?? box.center
        let position = position ?? anchor

        self.init(
            scale: scale,
            rotation: rotation,
            about: anchor,
            offset: Point(x: position.x - anchor.x + moved.x, y: position.y - anchor.y + moved.y)
        )
    }

    // MARK: - Public
    // MARK: - Private
}
