//
//  GradientRamp.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Frames

// A gradient's colours as a Core Graphics function of its position from 0 to 1, red, green, blue and alpha straight
// in the working space, which a shading lays along its line or out from its centre. The function holds the ramp, and
// Core Graphics releases it with the function.
final class GradientRamp: Sendable {
    // MARK: - Property
    private let gradient: Gradient

    // MARK: - Initializer
    init(_ gradient: Gradient) {
        self.gradient = gradient
    }

    // MARK: - Public
    func function() -> CGFunction? {
        var callbacks = CGFunctionCallbacks(
            version: 0,
            evaluate: { info, input, output in
                guard let info else { return }

                let ramp = Unmanaged<GradientRamp>.fromOpaque(info).takeUnretainedValue()
                for (index, channel) in ramp.gradient.channels(at: Double(input[0])).enumerated() {
                    output[index] = CGFloat(channel)
                }
            },
            releaseInfo: { info in
                guard let info else { return }

                Unmanaged<GradientRamp>.fromOpaque(info).release()
            }
        )
        let info = Unmanaged.passRetained(self).toOpaque()
        guard let function = CGFunction(
            info: info,
            domainDimension: 1,
            domain: [0, 1],
            rangeDimension: 4,
            range: [0, 1, 0, 1, 0, 1, 0, 1],
            callbacks: &callbacks
        ) else {
            Unmanaged<GradientRamp>.fromOpaque(info).release()
            return nil
        }

        return function
    }

    // MARK: - Private
}
