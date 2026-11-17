//
//  AffineTransform+TrackMotion.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A track's motion on one frame as a matrix: it carries a point as the motion's `carry` does.
extension AffineTransform {
    // MARK: - Property
    // MARK: - Initializer
    init(carrying motion: TrackMotion) {
        self.init(
            a: motion.scale,
            b: 0,
            c: 0,
            d: motion.scale,
            tx: motion.center.x - motion.origin.x * motion.scale,
            ty: motion.center.y - motion.origin.y * motion.scale
        )
    }

    // A band's motion keeps the full width of its picture: it takes only the vertical move and scale.
    init(carryingBand motion: TrackMotion) {
        self.init(
            a: 1,
            b: 0,
            c: 0,
            d: motion.scale,
            tx: 0,
            ty: motion.center.y - motion.origin.y * motion.scale
        )
    }

    // MARK: - Public
    // MARK: - Private
}
