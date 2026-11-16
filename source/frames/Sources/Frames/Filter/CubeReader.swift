//
//  CubeReader.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// Reads a 3D LUT in the Adobe and Resolve `.cube` format: keywords first (`TITLE`, `LUT_3D_SIZE`, `DOMAIN_MIN`,
// `DOMAIN_MAX` or Resolve's `LUT_3D_INPUT_RANGE`), then one line of red, green and blue per entry, with `#` comments
// and blank lines anywhere.
package struct CubeReader: Sendable {
    // MARK: - Property
    // The format's bounds on `LUT_3D_SIZE`.
    private let sizes = 2...256

    // MARK: - Initializer
    package init() {}

    // MARK: - Public
    package func read(contentsOf path: String) throws -> CubeLUT {
        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8)
        else {
            throw FilterError.unreadableCube(file: path)
        }

        return try read(text, file: path)
    }

    // `file` names the file in errors.
    package func read(
        _ text: String,
        file: String
    ) throws -> CubeLUT {
        var title: String?
        var size: Int?
        var domainMin = [0.0, 0.0, 0.0]
        var domainMax = [1.0, 1.0, 1.0]
        var domainLine = 0
        var values: [Double] = []
        // A CR LF pair is one Character, so lines split on every newline character.
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        for (index, line) in lines.enumerated() {
            let number = index + 1
            let words = line.split { $0 == " " || $0 == "\t" }
            guard let keyword = words.first, !keyword.hasPrefix("#") else { continue }

            if Double(keyword) != nil {
                guard let size else {
                    throw FilterError.malformedCube(file: file, line: number, reason: "an entry comes before LUT_3D_SIZE")
                }
                guard values.count < size * size * size * 3 else {
                    throw FilterError.malformedCube(
                        file: file,
                        line: number,
                        reason: "LUT_3D_SIZE \(size) takes \(size * size * size) entries, and this one is past them"
                    )
                }

                values += try triple(words, file: file, line: number, what: "an entry")
                continue
            }

            guard values.isEmpty else {
                throw FilterError.malformedCube(
                    file: file,
                    line: number,
                    reason: "\(keyword) comes after the entries, and keywords come before them"
                )
            }

            switch keyword {
            case "TITLE":
                title = line.drop { $0 != " " && $0 != "\t" }
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            case "LUT_3D_SIZE":
                guard words.count == 2, let written = Int(words[1]), sizes.contains(written) else {
                    throw FilterError.malformedCube(
                        file: file,
                        line: number,
                        reason: "LUT_3D_SIZE takes one whole number from \(sizes.lowerBound) to \(sizes.upperBound)"
                    )
                }

                size = written

            case "DOMAIN_MIN":
                domainMin = try triple(words.dropFirst(), file: file, line: number, what: "DOMAIN_MIN")
                domainLine = number

            case "DOMAIN_MAX":
                domainMax = try triple(words.dropFirst(), file: file, line: number, what: "DOMAIN_MAX")
                domainLine = number

            case "LUT_3D_INPUT_RANGE":
                let range = try numbers(words.dropFirst(), count: 2, file: file, line: number, what: String(keyword))
                domainMin = Array(repeating: range[0], count: 3)
                domainMax = Array(repeating: range[1], count: 3)
                domainLine = number

            case "LUT_1D_SIZE", "LUT_1D_INPUT_RANGE":
                throw FilterError.malformedCube(
                    file: file,
                    line: number,
                    reason: "\(keyword) belongs to a 1D LUT, and `lut` takes a 3D LUT (LUT_3D_SIZE)"
                )

            default:
                throw FilterError.malformedCube(file: file, line: number, reason: "\(keyword) is not a .cube keyword")
            }
        }

        guard let size else {
            throw FilterError.malformedCube(file: file, line: lines.count, reason: "the file has no LUT_3D_SIZE")
        }
        guard values.count == size * size * size * 3 else {
            throw FilterError.malformedCube(
                file: file,
                line: lines.count,
                reason: "LUT_3D_SIZE \(size) takes \(size * size * size) entries, and the file ends after "
                    + "\(values.count / 3)"
            )
        }
        guard zip(domainMin, domainMax).allSatisfy({ $0 < $1 }) else {
            throw FilterError.malformedCube(
                file: file,
                line: domainLine,
                reason: "the domain's minimum is not below its maximum on every channel"
            )
        }

        return CubeLUT(title: title, size: size, domainMin: domainMin, domainMax: domainMax, values: values)
    }

    // MARK: - Private
    private func triple(
        _ words: some Collection<Substring>,
        file: String,
        line: Int,
        what: String
    ) throws -> [Double] {
        try numbers(words, count: 3, file: file, line: line, what: what)
    }

    private func numbers(
        _ words: some Collection<Substring>,
        count: Int,
        file: String,
        line: Int,
        what: String
    ) throws -> [Double] {
        let values = words.compactMap { Double($0) }
        guard words.count == count, values.count == count, values.allSatisfy(\.isFinite) else {
            throw FilterError.malformedCube(file: file, line: line, reason: "\(what) takes \(count) numbers")
        }

        return values
    }
}
