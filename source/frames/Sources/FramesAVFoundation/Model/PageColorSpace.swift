//
//  PageColorSpace.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import Frames

// A colour space a page of a PDF draws or blends in (ISO 32000-1 8.6), with the formula of FRAMES-26 Media that takes
// its components to linear sRGB: DeviceRGB and DeviceGray as the page's untagged colour in `srgb`, CalRGB and CalGray by
// their gamma and matrix and the Bradford adaptation from their white to D65, Lab per ISO 32000-1 with a* and b*
// clamped to its range, an ICC profile by its tags as an image with that profile is read, Separation and DeviceN through
// their tint transform into their alternate space, and Indexed through its lookup into its base space. A space with no
// formula holds why in `noFormula`. A Pattern space is read by what its patterns draw, so it has no formula of its own.
indirect enum PageColorSpace: Equatable, Sendable {
    case deviceGray
    case deviceRGB
    case deviceCMYK
    case calGray(white: RGB, gamma: Double)
    case calRGB(white: RGB, gamma: [Double], matrix: ColorMatrix)
    case lab(white: RGB, range: [Double])
    case iccBased(componentCount: Int, color: Result<MediaColor, ColorRefusal>)
    case indexed(base: PageColorSpace, highValue: Int, lookup: [UInt8])
    case separation(alternate: PageColorSpace, tint: PDFFunction?)
    case deviceN(componentCount: Int, alternate: PageColorSpace, tint: PDFFunction?)
    case pattern(base: PageColorSpace?)
    case unknown(String)
    case malformed(String)

    // MARK: - Property
    private static let defaultLabRange: [Double] = [-100, 100, -100, 100]
    private static let d65 = RGB(red: 0.3127 / 0.3290, green: 1, blue: 0.3583 / 0.3290)
    private static let toLinearSRGB = ColorMatrix(normalizedPrimaryOf: .bt709).inverse

    // How the space is named in a refusal.
    var name: String {
        switch self {
        case .deviceGray:
            "DeviceGray"

        case .deviceRGB:
            "DeviceRGB"

        case .deviceCMYK:
            "DeviceCMYK"

        case let .calGray(_, gamma):
            "CalGray of Gamma \(gamma)"

        case let .calRGB(_, gamma, _):
            "CalRGB of Gamma \(gamma.map { "\($0)" }.joined(separator: " "))"

        case let .lab(_, range):
            "Lab of Range \(range.map { "\($0)" }.joined(separator: " "))"

        case let .iccBased(componentCount, _):
            "an ICCBased space of \(componentCount) components"

        case let .indexed(base, _, _):
            "Indexed over \(base.name)"

        case let .separation(alternate, _):
            "Separation over \(alternate.name)"

        case let .deviceN(_, alternate, _):
            "DeviceN over \(alternate.name)"

        case let .pattern(base):
            base.map { "Pattern over \($0.name)" } ?? "Pattern"

        case let .unknown(family):
            family

        case let .malformed(space):
            space
        }
    }

    // Why the space has no formula, nil where it has one.
    var noFormula: String? {
        switch self {
        case .deviceGray, .deviceRGB, .calGray, .calRGB, .lab:
            return nil

        case .deviceCMYK:
            return "DeviceCMYK, for which no formula is fixed"

        case let .iccBased(componentCount, color):
            guard case let .failure(refusal) = color else { return nil }

            return componentCount == 4
                ? "an ICCBased space of a CMYK profile, for which no formula is fixed"
                : "an ICCBased space whose profile \(refusal.reason.replacingOccurrences(of: "its ICC profile ", with: ""))"

        case let .indexed(base, _, _):
            return base.noFormula.map { "Indexed over \($0)" }

        case let .separation(alternate, tint), let .deviceN(_, alternate, tint):
            guard tint != nil else { return "\(name) whose tint transform this decoder does not evaluate" }

            return alternate.noFormula.map { "\(name.components(separatedBy: " ")[0]) over \($0)" }

        case let .pattern(base):
            return base?.noFormula.map { "Pattern over \($0)" }

        case let .unknown(family):
            return "the colour space \(family), which this decoder does not read"

        case let .malformed(space):
            return space
        }
    }

    var isUntagged: Bool {
        self == .deviceGray || self == .deviceRGB
    }

    var componentCount: Int {
        switch self {
        case .deviceGray, .calGray, .indexed, .separation:
            1

        case .deviceRGB, .calRGB, .lab:
            3

        case .deviceCMYK:
            4

        case let .iccBased(componentCount, _), let .deviceN(componentCount, _, _):
            componentCount

        case .pattern, .unknown, .malformed:
            0
        }
    }

    // The values of the space's components a ramp draws: each component alone and all together over a ramp for
    // DeviceN and a space of three, every index of an Indexed space, and a* and b* about the neutral axis for Lab.
    var rampValues: [[Double]] {
        let ramp = Self.ramp
        switch self {
        case let .indexed(_, highValue, _):
            return (0...highValue).map { [Double($0)] }

        case let .lab(_, range):
            let chroma: [Double] = [-60, -30, -10, 10, 30, 60]
            let neutral = ramp.map { [$0 * 100, 0, 0] }
            let colored: [[Double]] = [25.0, 50, 75].flatMap { lightness in
                chroma.flatMap { a in
                    chroma.map { b in
                        [lightness, min(max(a, range[0]), range[1]), min(max(b, range[2]), range[3])]
                    }
                }
            }

            return neutral + colored

        default:
            let count = componentCount
            guard count > 1 else { return ramp.map { [$0] } }
            let together = ramp.map { [Double](repeating: $0, count: count) }
            let alone = (0..<count).flatMap { component in
                ramp.map { value in (0..<count).map { $0 == component ? value : 0 } }
            }

            return together + alone
        }
    }

    // Encoded values from 0 to 1, dense near 0 and 1 and at the midpoints of 15, 255 and 1023 steps.
    private static let ramp: [Double] = [
        0, 0.0002, 0.0005, 0.001, 0.002, 0.003, 0.005, 0.0075, 0.01, 0.015, 0.02, 0.03, 0.04, 0.05, 0.07, 0.09, 0.1,
        0.15, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99, 0.995, 0.999, 1, 0.5 / 255, 1.5 / 255,
        10.5 / 255, 100.5 / 255, 200.5 / 255, 254.5 / 255, 0.5 / 1023, 3.5 / 1023, 1022.5 / 1023, 0.5 / 15, 7.5 / 15,
        14.5 / 15
    ]

    // MARK: - Initializer
    // The space `value` writes: a family name, or an array of a family and its parameters. A device name stands for
    // itself, as the resources that paint in it name no default space for it.
    init(_ value: PDFValue) {
        if let name = value.nameValue {
            self = Self.device(named: name) ?? .unknown(name)
            return
        }
        guard let elements = value.arrayValue, let family = elements.first?.nameValue else {
            self = .unknown("a colour space of no family")
            return
        }
        let parameter = { (index: Int) in elements.indices.contains(index) ? elements[index] : nil }

        switch family {
        case "CalGray":
            let entries = parameter(1)?.dictionaryValue ?? [:]
            self = .calGray(white: Self.white(of: entries), gamma: entries["Gamma"]?.number ?? 1)

        case "CalRGB":
            let entries = parameter(1)?.dictionaryValue ?? [:]
            let gamma = entries["Gamma"]?.numbers ?? [1, 1, 1]
            let written = entries["Matrix"]?.numbers ?? [1, 0, 0, 0, 1, 0, 0, 0, 1]
            let matrix = written.count == 9
                ? ColorMatrix(rows: (0..<3).map { row in (0..<3).map { column in written[column * 3 + row] } })
                : .identity
            self = .calRGB(white: Self.white(of: entries), gamma: gamma.count == 3 ? gamma : [1, 1, 1], matrix: matrix)

        case "Lab":
            let entries = parameter(1)?.dictionaryValue ?? [:]
            let range = entries["Range"]?.numbers ?? Self.defaultLabRange
            self = .lab(white: Self.white(of: entries), range: range.count == 4 ? range : Self.defaultLabRange)

        case "ICCBased":
            guard case let .stream(entries, profile)? = parameter(1) else {
                self = .unknown("an ICCBased space with no profile")
                return
            }
            guard let componentCount = entries["N"]?.integer(in: 1...4) else {
                self = .malformed("an ICCBased space whose N is not a whole number from 1 to 4")
                return
            }
            self = .iccBased(componentCount: componentCount, color: ICCProfileReader(data: profile).color())

        case "Indexed", "I":
            let base = parameter(1).map(PageColorSpace.init) ?? .unknown("Indexed with no base")
            let lookup: [UInt8] = switch parameter(3) {
            case let .string(bytes)?, let .stream(_, bytes)?:
                [UInt8](bytes)

            default:
                []
            }
            guard let highValue = parameter(2)?.integer(in: 0...255) else {
                self = .malformed("an Indexed space whose hival is not a whole number from 0 to 255")
                return
            }
            self = .indexed(base: base, highValue: highValue, lookup: lookup)

        case "Separation":
            self = .separation(
                alternate: parameter(2).map(PageColorSpace.init) ?? .unknown("Separation with no alternate"),
                tint: parameter(3).flatMap(PDFFunction.init)
            )

        case "DeviceN":
            self = .deviceN(
                componentCount: parameter(1)?.arrayValue?.count ?? 0,
                alternate: parameter(2).map(PageColorSpace.init) ?? .unknown("DeviceN with no alternate"),
                tint: parameter(3).flatMap(PDFFunction.init)
            )

        case "Pattern":
            self = .pattern(base: parameter(1).map(PageColorSpace.init))

        default:
            self = Self.device(named: family) ?? .unknown(family)
        }
    }

    // MARK: - Public
    // The linear sRGB the formula gives `components`, nil for a space with no formula.
    func linear(_ components: [Double]) -> RGB? {
        guard noFormula == nil else { return nil }
        let component = { (index: Int) in components.indices.contains(index) ? components[index] : 0 }

        switch self {
        case .deviceGray:
            return TransferFunction.sRGB.decode(RGB(red: component(0), green: component(0), blue: component(0)))

        case .deviceRGB:
            return TransferFunction.sRGB.decode(RGB(red: component(0), green: component(1), blue: component(2)))

        case let .calGray(_, gamma):
            let luminance = pow(min(max(component(0), 0), 1), gamma)

            return RGB(red: luminance, green: luminance, blue: luminance)

        case let .calRGB(white, gamma, matrix):
            let powered = RGB(
                red: pow(min(max(component(0), 0), 1), gamma[0]),
                green: pow(min(max(component(1), 0), 1), gamma[1]),
                blue: pow(min(max(component(2), 0), 1), gamma[2])
            )

            return Self.linear(tristimulus: matrix.applied(to: powered), white: white)

        case let .lab(white, range):
            let lightness = min(max(component(0), 0), 100)
            let a = min(max(component(1), range[0]), range[1])
            let b = min(max(component(2), range[2]), range[3])
            let m = (lightness + 16) / 116
            let l = m + a / 500
            let n = m - b / 200
            let g = { (x: Double) in x >= 6.0 / 29 ? x * x * x : 108.0 / 841 * (x - 4.0 / 29) }
            let tristimulus = RGB(red: white.red * g(l), green: white.green * g(m), blue: white.blue * g(n))

            return Self.linear(tristimulus: tristimulus, white: white)

        case let .iccBased(componentCount, color):
            guard case let .success(color) = color else { return nil }
            let encoded = componentCount == 1
                ? RGB(red: component(0), green: component(0), blue: component(0))
                : RGB(red: component(0), green: component(1), blue: component(2))

            return TransferFunction.sRGB.decode(MediaColorConversion(color).working(encoded, toneMapping: nil))

        case let .indexed(base, highValue, lookup):
            let index = min(max(Int(component(0).rounded()), 0), highValue)
            let count = base.componentCount
            guard lookup.count >= (index + 1) * count else { return nil }
            let bytes = lookup[index * count..<(index + 1) * count].map { Double($0) / 255 }

            return base.linear(base.components(ofLookup: bytes))

        case let .separation(alternate, tint), let .deviceN(_, alternate, tint):
            guard let tint, let alternateComponents = tint(components) else { return nil }

            return alternate.linear(alternateComponents)

        case .deviceCMYK, .pattern, .unknown, .malformed:
            return nil
        }
    }

    // MARK: - Private
    private static func device(named name: String) -> PageColorSpace? {
        switch name {
        case "DeviceGray", "G":
            .deviceGray

        case "DeviceRGB", "RGB":
            .deviceRGB

        case "DeviceCMYK", "CMYK":
            .deviceCMYK

        case "Pattern":
            .pattern(base: nil)

        default:
            nil
        }
    }

    // A CalGray, CalRGB or Lab space's `WhitePoint`, normalised to Y 1, and D65 where it writes none.
    private static func white(of entries: [String: PDFValue]) -> RGB {
        guard let white = entries["WhitePoint"]?.numbers, white.count == 3, white[1] > 0 else { return d65 }

        return RGB(red: white[0] / white[1], green: 1, blue: white[2] / white[1])
    }

    // CIE XYZ relative to `white` to linear sRGB: N_sRGB⁻¹ × D × XYZ, D the Bradford adaptation from `white` to D65.
    private static func linear(
        tristimulus: RGB,
        white: RGB
    ) -> RGB {
        toLinearSRGB.multiplied(by: ColorMatrix(bradfordFrom: white, to: d65)).applied(to: tristimulus)
    }

    // An Indexed lookup's bytes, each from 0 to 1, as the components of this base space: a Lab space's over its
    // ranges, and every other space's as they are.
    private func components(ofLookup bytes: [Double]) -> [Double] {
        guard case let .lab(_, range) = self, bytes.count == 3 else { return bytes }

        return [bytes[0] * 100, range[0] + bytes[1] * (range[1] - range[0]), range[2] + bytes[2] * (range[3] - range[2])]
    }
}
