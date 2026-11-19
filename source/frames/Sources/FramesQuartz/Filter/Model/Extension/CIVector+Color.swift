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
    // The colour's working value in the form `compositing` names, premultiplied by its alpha.
    convenience init(
        premultiplied color: Color,
        compositing: Compositing
    ) {
        let encoded = RGB(red: color.red, green: color.green, blue: color.blue)
        let value = compositing == .linear ? TransferFunction.sRGB.decode(encoded) : encoded
        self.init(
            x: value.red * color.alpha,
            y: value.green * color.alpha,
            z: value.blue * color.alpha,
            w: color.alpha
        )
    }

    // MARK: - Public
    // MARK: - Private
}
