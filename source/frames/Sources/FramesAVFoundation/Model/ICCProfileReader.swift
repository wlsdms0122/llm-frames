//
//  ICCProfileReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/20/26.
//

import Foundation
import Frames

// Reads the colour an ICC profile (ICC.1, with the `cicp` tag of ICC.1 v4.4) names, as FRAMES-26 Media takes an
// image's: its code points where it carries a `cicp` tag, its matrix and tone-curve profile where it has colorant and
// tone curve tags and no lookup table, and otherwise no colour a fixed formula converts. Numbers are big-endian.
struct ICCProfileReader {
    // MARK: - Property
    // A one-entry `curv` stores its gamma in u8Fixed8, so the stored values nearest 1.8, 2.2 and 2.4 stand for them
    // (FRAMES-26 Media).
    private static let storedGammas: [Int: Double] = [461: 1.8, 563: 2.2, 614: 2.4]

    private let bytes: [UInt8]

    // MARK: - Initializer
    init(data: Data) {
        self.bytes = [UInt8](data)
    }

    // MARK: - Public
    // What the profile names, or why no fixed formula converts it.
    func color() -> Result<MediaColor, ColorRefusal> {
        let tags = tagTable()
        if let cicp = tags["cicp"], let codePoints = codePoints(at: cicp) {
            return MediaColor(codePoints: codePoints).map { .success($0) }
                ?? .failure(.reservedCodePoints(codePoints))
        }
        guard !tags.keys.contains(where: { $0.hasPrefix("A2B") || $0.hasPrefix("B2A") || $0.hasPrefix("D2B") }) else {
            return .failure(.lookupTableProfile)
        }

        switch signature(at: 16) {
        case "RGB ":
            guard
                let red = tags["rXYZ"].flatMap(tristimulus),
                let green = tags["gXYZ"].flatMap(tristimulus),
                let blue = tags["bXYZ"].flatMap(tristimulus),
                let redCurve = tags["rTRC"].flatMap(curve),
                let greenCurve = tags["gTRC"].flatMap(curve),
                let blueCurve = tags["bTRC"].flatMap(curve)
            else {
                return .failure(.lookupTableProfile)
            }
            let colorants = ColorMatrix(rows: [
                [red.red, green.red, blue.red],
                [red.green, green.green, blue.green],
                [red.blue, green.blue, blue.blue]
            ])

            return .success(MediaColor(profile: MatrixProfile(
                curves: [redCurve, greenCurve, blueCurve],
                colorants: colorants
            )))

        case "GRAY":
            guard let grey = tags["kTRC"].flatMap(curve) else { return .failure(.lookupTableProfile) }

            return .success(MediaColor(profile: MatrixProfile(greyCurve: grey)))

        default:
            return .failure(.lookupTableProfile)
        }
    }

    // MARK: - Private
    // Each tag's signature and the offset of its element.
    private func tagTable() -> [String: Int] {
        guard let count = uint32(at: 128) else { return [:] }
        var tags: [String: Int] = [:]
        for index in 0..<count {
            let entry = 132 + index * 12
            guard let signature = signature(at: entry), let offset = uint32(at: entry + 4) else { break }
            tags[signature] = offset
        }

        return tags
    }

    // A `cicp` element: colour primaries, transfer characteristics, matrix coefficients, video full range flag.
    private func codePoints(at offset: Int) -> CodePoints? {
        guard signature(at: offset) == "cicp", bytes.count >= offset + 12 else { return nil }

        return CodePoints(
            colorPrimaries: Int(bytes[offset + 8]),
            transferCharacteristics: Int(bytes[offset + 9]),
            matrixCoefficients: Int(bytes[offset + 10])
        )
    }

    // An `XYZ ` element's first value.
    private func tristimulus(at offset: Int) -> RGB? {
        guard
            signature(at: offset) == "XYZ ",
            let x = fixed(at: offset + 8),
            let y = fixed(at: offset + 12),
            let z = fixed(at: offset + 16)
        else {
            return nil
        }

        return RGB(red: x, green: y, blue: z)
    }

    // A `curv` or `para` element.
    private func curve(at offset: Int) -> ToneCurve? {
        switch signature(at: offset) {
        case "curv":
            guard let count = uint32(at: offset + 8), bytes.count >= offset + 12 + count * 2 else { return nil }
            let entries = (0..<count).compactMap { uint16(at: offset + 12 + $0 * 2) }

            switch count {
            case 0:
                return .gamma(1)

            case 1:
                return .gamma(Self.storedGammas[entries[0]] ?? Double(entries[0]) / 256)

            default:
                return .table(entries.map { Double($0) / 65535 })
            }

        case "para":
            guard let functionType = uint16(at: offset + 8), functionType <= 4 else { return nil }
            let count = [1, 3, 4, 5, 7][functionType]
            let parameters = (0..<count).compactMap { fixed(at: offset + 12 + $0 * 4) }
            guard parameters.count == count else { return nil }

            return .parametric(functionType: functionType, parameters: parameters)

        default:
            return nil
        }
    }

    private func signature(at offset: Int) -> String? {
        guard bytes.count >= offset + 4 else { return nil }

        return String(bytes: bytes[offset..<offset + 4], encoding: .ascii)
    }

    private func uint16(at offset: Int) -> Int? {
        guard bytes.count >= offset + 2 else { return nil }

        return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
    }

    private func uint32(at offset: Int) -> Int? {
        guard bytes.count >= offset + 4 else { return nil }

        return (0..<4).reduce(0) { value, index in value << 8 | Int(bytes[offset + index]) }
    }

    // An s15Fixed16Number.
    private func fixed(at offset: Int) -> Double? {
        uint32(at: offset).map { Double(Int32(bitPattern: UInt32($0))) / 65536 }
    }
}
