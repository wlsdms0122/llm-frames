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
// of the premultiplied colours. The non-separable modes use W3C's Lum, Sat, SetLum, SetSat and ClipColor.
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

        let mixedColor = mixed(mode, backdrop: Array(backdrop.prefix(3)), source: Array(source.prefix(3)))
        let color = (0..<3).map { channel in
            sourceAlpha * source[channel] * (1 - backdropAlpha)
                + backdropAlpha * backdrop[channel] * (1 - sourceAlpha)
                + sourceAlpha * backdropAlpha * mixedColor[channel]
        }

        return color + [sourceAlpha + backdropAlpha * (1 - sourceAlpha)]
    }

    // MARK: - Private
    private func mixed(
        _ mode: BlendMode,
        backdrop cb: [Double],
        source cs: [Double]
    ) -> [Double] {
        switch mode {
        case .hue:
            setLum(setSat(cs, sat(cb)), lum(cb))

        case .saturation:
            setLum(setSat(cb, sat(cs)), lum(cb))

        case .color:
            setLum(cs, lum(cb))

        case .luminosity:
            setLum(cb, lum(cs))

        default:
            zip(cb, cs).map { mixed(mode, backdrop: $0, source: $1) }
        }
    }

    private func mixed(
        _ mode: BlendMode,
        backdrop cb: Double,
        source cs: Double
    ) -> Double {
        switch mode {
        case .normal, .plusLighter, .hue, .saturation, .color, .luminosity:
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

    private func lum(_ color: [Double]) -> Double {
        0.3 * color[0] + 0.59 * color[1] + 0.11 * color[2]
    }

    private func sat(_ color: [Double]) -> Double {
        color.max()! - color.min()!
    }

    private func clipColor(_ color: [Double]) -> [Double] {
        let luminance = lum(color)
        let lowest = color.min()!
        let highest = color.max()!
        var clipped = color
        if lowest < 0 {
            clipped = clipped.map { luminance + ($0 - luminance) * luminance / (luminance - lowest) }
        }
        if highest > 1 {
            clipped = clipped.map { luminance + ($0 - luminance) * (1 - luminance) / (highest - luminance) }
        }

        return clipped
    }

    private func setLum(
        _ color: [Double],
        _ luminance: Double
    ) -> [Double] {
        let shift = luminance - lum(color)

        return clipColor(color.map { $0 + shift })
    }

    // W3C's SetSat names Cmax, Cmid and Cmin; scaling each channel's distance from Cmin is the same function.
    private func setSat(
        _ color: [Double],
        _ saturation: Double
    ) -> [Double] {
        let lowest = color.min()!
        let highest = color.max()!
        guard highest > lowest else { return [0, 0, 0] }

        return color.map { ($0 - lowest) * saturation / (highest - lowest) }
    }
}
