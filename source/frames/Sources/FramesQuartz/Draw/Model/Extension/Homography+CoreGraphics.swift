//
//  Homography+CoreGraphics.swift
//  FramesQuartz
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Frames

extension Homography {
    // MARK: - Property
    // MARK: - Initializer
    init(_ transform: CGAffineTransform) {
        self.init(
            Frames.AffineTransform(
                a: Double(transform.a),
                b: Double(transform.b),
                c: Double(transform.c),
                d: Double(transform.d),
                tx: Double(transform.tx),
                ty: Double(transform.ty)
            )
        )
    }

    // MARK: - Public
    // MARK: - Private
}
