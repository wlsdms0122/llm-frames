//
//  GradientRamp.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Frames

// A gradient's colours as a Core Graphics function of its position from 0 to 1, red, green, blue and alpha straight
// on the encoded form, the colours unbounded and alpha from 0 to 1, which a shading lays along its line or out from
// its centre. The function holds the ramp, and
// Core Graphics releases it with the function.
final class GradientRamp: Sendable {
    // MARK: - Property
    // The bound of a colour channel in the function's range, which Core Graphics clips to: further than any colour
    // half float holds.
    private static let reach: CGFloat = 65_504
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
            range: [-Self.reach, Self.reach, -Self.reach, Self.reach, -Self.reach, Self.reach, 0, 1],
            callbacks: &callbacks
        ) else {
            Unmanaged<GradientRamp>.fromOpaque(info).release()
            return nil
        }

        return function
    }

    // MARK: - Private
}
