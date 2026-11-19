//
//  BlendFormula.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
@testable import FramesQuartz

// The W3C Compositing and Blending Level 1 formulas as FRAMES-26 reads them, on unpremultiplied encoded RGBA,
// unbounded, giving premultiplied encoded RGBA: co = cs (1 - ab) + cb (1 - as) + as ab B(Cb, Cs) and
// ao = as + ab (1 - as) in the form `compositing` names, B computed in that form for a form-free mode and on the
// encoded form for the others, `add` the unbounded sum of the premultiplied colours and `plus-lighter` their sum
// bounded by 1. The non-separable modes use W3C's Lum, Sat, SetLum, SetSat and ClipColor.
struct BlendFormula {
    // MARK: - Property
    private static let encodedModes: Set<BlendMode> = [
        .overlay, .hardLight, .softLight, .exclusion, .hue, .saturation, .color, .luminosity
    ]

    // MARK: - Initializer
    // MARK: - Public
    func composite(
        _ mode: BlendMode,
        source: [Double],
        backdrop: [Double],
        compositing: Compositing = .encoded
    ) -> [Double] {
        let linear = compositing == .linear
        let toForm: (Double) -> Double = { linear ? TransferFunction.sRGB.decode($0) : $0 }
        let fromForm: (Double) -> Double = { linear ? TransferFunction.sRGB.encode($0) : $0 }
        let sourceAlpha = source[3]
        let backdropAlpha = backdrop[3]
        let cs = source.prefix(3).map(toForm)
        let cb = backdrop.prefix(3).map(toForm)

        let premultiplied: [Double]
        switch mode {
        case .plusLighter:
            premultiplied = (0..<3).map { min(1, cs[$0] * sourceAlpha + cb[$0] * backdropAlpha) }
                + [min(1, sourceAlpha + backdropAlpha)]

        case .add:
            premultiplied = (0..<3).map { cs[$0] * sourceAlpha + cb[$0] * backdropAlpha }
                + [sourceAlpha + backdropAlpha * (1 - sourceAlpha)]

        default:
            let mixedColor = Self.encodedModes.contains(mode)
                ? mixed(mode, backdrop: Array(backdrop.prefix(3)), source: Array(source.prefix(3))).map(toForm)
                : mixed(mode, backdrop: cb, source: cs)
            let color = (0..<3).map { channel in
                sourceAlpha * cs[channel] * (1 - backdropAlpha)
                    + backdropAlpha * cb[channel] * (1 - sourceAlpha)
                    + sourceAlpha * backdropAlpha * mixedColor[channel]
            }
            premultiplied = color + [sourceAlpha + backdropAlpha * (1 - sourceAlpha)]
        }

        let alpha = premultiplied[3]
        guard alpha > 0 else { return [0, 0, 0, 0] }

        return premultiplied.prefix(3).map { fromForm($0 / alpha) * alpha } + [alpha]
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
        case .normal, .plusLighter, .add, .hue, .saturation, .color, .luminosity:
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
        if lowest < 0, luminance > lowest {
            clipped = clipped.map { luminance + ($0 - luminance) * luminance / (luminance - lowest) }
        }
        if highest > 1, highest > luminance {
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
