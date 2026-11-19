//
//  CIVector+Color.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreImage
import Frames

extension CIVector {
    // MARK: - Property
    // MARK: - Initializer
    // The encoded working value premultiplied by its alpha.
    convenience init(premultiplied color: Color) {
        self.init(
            x: color.red * color.alpha,
            y: color.green * color.alpha,
            z: color.blue * color.alpha,
            w: color.alpha
        )
    }

    // MARK: - Public
    // MARK: - Private
}
