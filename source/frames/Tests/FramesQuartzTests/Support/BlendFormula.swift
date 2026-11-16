//
//  BlendFormula.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
@testable import FramesQuartz

// The W3C Compositing and Blending Level 1 formulas on unpremultiplied RGBA from 0 to 1, giving premultiplied RGBA:
// co = cs (1 - ab) + cb (1 - as) + as ab B(Cb, Cs) and ao = as + ab (1 - as), and for `plus-lighter` the clamped sum
// of the premultiplied colours.
struct BlendFormula {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func composite(
        _ mode: BlendMode,
        source: [Double],
        backdrop: [Double]
    ) -> [Double] {
        let sourceAlpha = source[3]
        let backdropAlpha = backdrop[3]
        guard mode != .plusLighter else {
            return (0..<3).map { min(1, source[$0] * sourceAlpha + backdrop[$0] * backdropAlpha) }
                + [min(1, sourceAlpha + backdropAlpha)]
        }

        let color = (0..<3).map { channel in
            let cs = source[channel]
            let cb = backdrop[channel]

            return sourceAlpha * cs * (1 - backdropAlpha)
                + backdropAlpha * cb * (1 - sourceAlpha)
                + sourceAlpha * backdropAlpha * mixed(mode, backdrop: cb, source: cs)
        }

        return color + [sourceAlpha + backdropAlpha * (1 - sourceAlpha)]
    }

    // MARK: - Private
    private func mixed(
        _ mode: BlendMode,
        backdrop cb: Double,
        source cs: Double
    ) -> Double {
        switch mode {
        case .normal, .plusLighter:
            cs

        case .multiply:
            cb * cs

        case .screen:
            cb + cs - cb * cs

        case .overlay:
            hardLight(backdrop: cs, source: cb)

        case .darken:
            min(cb, cs)

        case .lighten:
            max(cb, cs)

        case .colorDodge:
            cb == 0 ? 0 : (cs == 1 ? 1 : min(1, cb / (1 - cs)))

        case .colorBurn:
            cb == 1 ? 1 : (cs == 0 ? 0 : 1 - min(1, (1 - cb) / cs))

        case .hardLight:
            hardLight(backdrop: cb, source: cs)

        case .softLight:
            softLight(backdrop: cb, source: cs)

        case .difference:
            abs(cb - cs)

        case .exclusion:
            cb + cs - 2 * cb * cs
        }
    }

    private func hardLight(
        backdrop cb: Double,
        source cs: Double
    ) -> Double {
        cs <= 0.5 ? cb * 2 * cs : cb + (2 * cs - 1) - cb * (2 * cs - 1)
    }

    private func softLight(
        backdrop cb: Double,
        source cs: Double
    ) -> Double {
        guard cs > 0.5 else { return cb - (1 - 2 * cs) * cb * (1 - cb) }

        let darkened = cb <= 0.25 ? ((16 * cb - 12) * cb + 4) * cb : cb.squareRoot()

        return cb + (2 * cs - 1) * (darkened - cb)
    }
}
