//
//  CGAffineTransform+AffineTransform.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Frames

extension CGAffineTransform {
    // MARK: - Property
    // MARK: - Initializer
    init(_ transform: Frames.AffineTransform) {
        self.init(a: transform.a, b: transform.b, c: transform.c, d: transform.d, tx: transform.tx, ty: transform.ty)
    }

    // MARK: - Public
    // MARK: - Private
}
