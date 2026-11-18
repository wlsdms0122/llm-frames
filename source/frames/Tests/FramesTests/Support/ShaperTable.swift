//
//  ShaperTable.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

@testable import Frames

// A fake shaping provider. The machine has the `installed` families, a pack's file holds the family its name starts
// with, every file holds a face of any name, and every face has an ascent of 0.8 and a descent of 0.2. Each scalar is
// one glyph whose id is its value and whose advance is its width in `advances` times the size, 0.5 when not listed.
// Scalars in `missing` are set in the fallback face.
struct ShaperTable: ShapingProvider {
    // MARK: - Property
    static let fallback = FontFace(file: "/System/Fallback.ttc", name: "Fallback", ascent: 0.8, descent: 0.2)

    let installed: Set<String>
    let advances: [Unicode.Scalar: Double]
    let missing: Set<Unicode.Scalar>

    // MARK: - Initializer
    init(
        installed: Set<String> = ["Apple SD Gothic Neo"],
        advances: [Unicode.Scalar: Double] = [" ": 0.25],
        missing: Set<Unicode.Scalar> = []
    ) {
        self.installed = installed
        self.advances = advances
        self.missing = missing
    }

    // MARK: - Public
    static func face(
        _ family: String,
        _ weight: FontWeight,
        file: String? = nil
    ) -> FontFace {
        FontFace(
            file: file ?? "/System/\(family).ttc",
            name: "\(family)-\(weight.rawValue)",
            ascent: 0.8,
            descent: 0.2
        )
    }

    func face(
        family: String,
        weight: FontWeight,
        in files: [String]
    ) -> FontFace? {
        let prefix = family.replacingOccurrences(of: " ", with: "")
        let file = files.first { $0.split(separator: "/").last?.hasPrefix(prefix) ?? false }

        return file.map { Self.face(family, weight, file: $0) }
    }

    func face(
        named name: String,
        in file: String
    ) -> FontFace? {
        FontFace(file: file, name: name, ascent: 0.8, descent: 0.2)
    }

    func installedFace(
        family: String,
        weight: FontWeight
    ) -> FontFace? {
        installed.contains(family) ? Self.face(family, weight) : nil
    }

    func shape(
        _ text: String,
        face: FontFace,
        size: Double
    ) -> [ShapedRun] {
        Array(text.unicodeScalars).enumerated().reduce(into: [ShapedRun]()) { runs, element in
            let (offset, scalar) = element
            let runFace = missing.contains(scalar) ? Self.fallback : face
            let glyph = ShapedGlyph(id: Int(scalar.value), advance: (advances[scalar] ?? 0.5) * size, offset: offset)

            if let last = runs.last, last.face == runFace {
                runs[runs.count - 1] = ShapedRun(face: runFace, glyphs: last.glyphs + [glyph])
            } else {
                runs.append(ShapedRun(face: runFace, glyphs: [glyph]))
            }
        }
    }

    // MARK: - Private
}
