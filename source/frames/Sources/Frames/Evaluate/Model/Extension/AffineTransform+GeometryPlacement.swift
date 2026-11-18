//
//  AffineTransform+GeometryPlacement.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The own transform of a shape placed by its geometry (FRAMES-1). `box` is its geometry's box in the space it is
// written in, and `outset` how far that box is grown on every side there. The shape scales and turns about its anchor
// point, the point of the grown box `anchor` names or else the box's centre, and its position, when it has one, moves
// that point there. `moved` moves it further, in fractions of the grown box's width and height.
extension AffineTransform {
    // MARK: - Property
    // MARK: - Initializer
    init(
        placing box: Rectangle,
        outset: Double,
        anchor: NamedPoint?,
        position: Point?,
        scale: Double,
        rotation: Double,
        moved: Point = Point(x: 0, y: 0)
    ) {
        let grown = box.grown(by: outset)
        let anchor = anchor?.point(grownBy: outset) ?? grown.center
        let position = position ?? anchor

        self.init(
            scale: scale,
            rotation: rotation,
            about: anchor,
            offset: Point(
                x: position.x - anchor.x + moved.x * grown.width,
                y: position.y - anchor.y + moved.y * grown.height
            )
        )
    }

    // MARK: - Public
    // MARK: - Private
}
