//
//  ShaperTable.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

@testable import Frames

// A shaping provider over a table. Every family it has holds a regular and a bold upright face unless `styles` names
// its faces, and a pack's family is in the file whose name starts with the family's. Each scalar is a glyph `advances`
// wide in ems, `fi` is one ligature glyph an em wide unless `liga` is 0, and `AV` kerns by a tenth of an em unless
// `kern` is 0. A character `lacks` names for a family is set in the next face, and one in `missing` or that no face
// has in `fallback`.
struct ShaperTable: ShapingProvider {
    // MARK: - Property
    static let fallback = face("Fallback", .regular, file: "/System/Fallback.ttc")
    static let ligature = 0xFB01
    static let kerning = 0.1

    let installed: Set<String>
    let advances: [Unicode.Scalar: Double]
    let missing: Set<Unicode.Scalar>
    let lacks: [String: Set<Unicode.Scalar>]
    let styles: [String: [(weight: FontWeight, style: FontStyle, width: Int)]]

    // MARK: - Initializer
    init(
        installed: Set<String> = ["Apple SD Gothic Neo"],
        advances: [Unicode.Scalar: Double] = [" ": 0.25],
        missing: Set<Unicode.Scalar> = [],
        lacks: [String: Set<Unicode.Scalar>] = [:],
        styles: [String: [(weight: FontWeight, style: FontStyle, width: Int)]] = [:]
    ) {
        self.installed = installed
        self.advances = advances
        self.missing = missing
        self.lacks = lacks
        self.styles = styles
    }

    // MARK: - Public
    static func face(
        _ family: String,
        _ weight: FontWeight,
        style: FontStyle = .upright,
        width: Int = 5,
        file: String? = nil
    ) -> FontFace {
        let suffix = (style == .upright ? "" : "-\(style.rawValue)") + (width == 5 ? "" : "-w\(width)")

        return FontFace(
            file: file ?? "/System/\(family).ttc",
            name: "\(family)-\(weight.written)\(suffix)",
            weight: weight,
            width: width,
            style: style,
            ascent: 0.8,
            descent: 0.2,
            underlineOffset: 0.1,
            underlineThickness: 0.05
        )
    }

    func faces(
        family: String,
        in files: [String]
    ) -> [FontFace] {
        let prefix = family.replacingOccurrences(of: " ", with: "")
        let file = files.first { $0.split(separator: "/").last?.hasPrefix(prefix) ?? false }

        return file.map { faces(of: family, file: $0) } ?? []
    }

    func face(
        named name: String,
        in file: String
    ) -> FontFace? {
        FontFace(
            file: file,
            name: name,
            weight: .regular,
            width: 5,
            style: .upright,
            ascent: 0.8,
            descent: 0.2,
            underlineOffset: 0.1,
            underlineThickness: 0.05
        )
    }

    func installedFaces(family: String) -> [FontFace] {
        installed.contains(family) ? faces(of: family, file: nil) : []
    }

    func shape(
        _ text: String,
        faces: [FontFace],
        size: Double,
        features: [FontFeature],
        weight: FontWeight,
        italic: Bool
    ) -> [ShapedRun] {
        let isLigated = !features.contains(FontFeature(tag: "liga", value: 0))
        let isKerned = !features.contains(FontFeature(tag: "kern", value: 0))
        let scalars = Array(text.unicodeScalars)

        var runs: [ShapedRun] = []
        var offset = 0
        while offset < scalars.count {
            let scalar = scalars[offset]
            let next = scalars.indices.contains(offset + 1) ? scalars[offset + 1] : nil
            let runFace = face(for: scalar, among: faces)
            let isLigature = isLigated && scalar == "f" && next == "i"
            let kern = isKerned && scalar == "A" && next == "V" ? Self.kerning : 0
            let advance = isLigature ? 1 : (advances[scalar] ?? 0.5) - kern
            let glyph = ShapedGlyph(
                id: isLigature ? Self.ligature : Int(scalar.value),
                advance: advance * size,
                offset: offset
            )

            if let last = runs.last, last.face == runFace {
                runs[runs.count - 1] = ShapedRun(face: runFace, glyphs: last.glyphs + [glyph])
            } else {
                runs.append(ShapedRun(face: runFace, glyphs: [glyph]))
            }
            offset += isLigature ? 2 : 1
        }

        return runs
    }

    // MARK: - Private
    private func faces(
        of family: String,
        file: String?
    ) -> [FontFace] {
        let listed = styles[family] ?? [(.regular, .upright, 5), (.bold, .upright, 5)]

        return listed.map { Self.face(family, $0.weight, style: $0.style, width: $0.width, file: file) }
    }

    private func face(
        for scalar: Unicode.Scalar,
        among faces: [FontFace]
    ) -> FontFace {
        guard !missing.contains(scalar) else { return Self.fallback }

        let found = faces.first { face in
            !lacks.contains { family, scalars in face.name.hasPrefix(family + "-") && scalars.contains(scalar) }
        }

        return found ?? Self.fallback
    }
}
