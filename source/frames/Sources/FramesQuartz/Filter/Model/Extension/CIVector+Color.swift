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
    // The colour premultiplied by its alpha, each component from 0 to 1 as written, sRGB encoded. `Color` holds
    // eight hexadecimal digits.
    convenience init(premultiplied color: Color) {
        let value = UInt32(color.hex.dropFirst(), radix: 16)!
        let alpha = Double(value & 0xFF) / 255

        self.init(
            x: Double(value >> 24 & 0xFF) / 255 * alpha,
            y: Double(value >> 16 & 0xFF) / 255 * alpha,
            z: Double(value >> 8 & 0xFF) / 255 * alpha,
            w: alpha
        )
    }

    // MARK: - Public
    // MARK: - Private
}
