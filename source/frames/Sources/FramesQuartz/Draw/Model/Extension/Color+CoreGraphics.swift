//
//  Color+CoreGraphics.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Frames

extension Color {
    // MARK: - Property
    // The colour's sRGB components from its `#RRGGBBAA` digits, as Core Graphics draws them.
    var cgColor: CGColor {
        let digits = Array(hex.dropFirst())
        let components = stride(from: 0, to: 8, by: 2).map { start in
            CGFloat(Int(String(digits[start..<start + 2]), radix: 16) ?? 0) / 255
        }

        return CGColor(colorSpace: WorkingSpace.colorSpace, components: components)!
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
