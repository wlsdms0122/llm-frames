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
    // The encoded working value's red, green, blue and alpha, as Core Graphics draws them.
    var cgColor: CGColor {
        let components = [red, green, blue, alpha].map { CGFloat($0) }

        return CGColor(colorSpace: WorkingSpace.colorSpace, components: components)!
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
