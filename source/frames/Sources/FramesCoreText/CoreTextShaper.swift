//
//  CoreTextShaper.swift
//  FramesCoreText
//
//  Created by JSilver on 11/16/26.
//

import CoreText
import Foundation
import Frames

// The `coretext` shaping provider. A face is named by its PostScript name within its file, and its weight, width and
// style are read from its OS/2 table. A run is set as a CoreText line sets it, with the feature settings given over
// the font's defaults, in a font whose cascade list is the later faces given; characters none of them has fall back
// to the face CoreText's own cascade finds on the machine for the first face, which follows its weight and slant.
package struct CoreTextShaper: Sendable {
    // MARK: - Property
    // Offsets into the OS/2 table: `usWeightClass`, `usWidthClass` and `fsSelection`, whose bit 0 is italic and bit 9
    // oblique.
    private static let weightClassOffset = 4
    private static let widthClassOffset = 6
    private static let selectionOffset = 62

    // MARK: - Initializer
    package init() {}

    // MARK: - Public
    // MARK: - Private
    private func face(
        of font: CTFont,
        file: String
    ) -> FontFace {
        let unit = CTFontCreateCopyWithAttributes(font, 1, nil, nil)
        let table = CTFontCopyTable(unit, CTFontTableTag(kCTFontTableOS2), []) as Data?
        let isItalic = CTFontGetSymbolicTraits(unit).contains(.traitItalic)
        let selection = table.flatMap { uint16(in: $0, at: Self.selectionOffset) }
        let style: FontStyle = if let selection {
            selection & 1 != 0 ? .italic : selection & (1 << 9) != 0 ? .oblique : .upright
        } else {
            isItalic ? .italic : .upright
        }

        return FontFace(
            file: file,
            name: CTFontCopyPostScriptName(font) as String,
            weight: FontWeight(table.flatMap { uint16(in: $0, at: Self.weightClassOffset) }.map(Int.init) ?? 400),
            width: table.flatMap { uint16(in: $0, at: Self.widthClassOffset) }.map(Int.init) ?? 5,
            style: style,
            ascent: Double(CTFontGetAscent(unit)),
            descent: Double(CTFontGetDescent(unit)),
            underlineOffset: -Double(CTFontGetUnderlinePosition(unit)),
            underlineThickness: Double(CTFontGetUnderlineThickness(unit))
        )
    }

    private func uint16(
        in table: Data,
        at offset: Int
    ) -> UInt16? {
        guard table.count >= offset + 2 else { return nil }
        let start = table.startIndex + offset

        return UInt16(table[start]) << 8 | UInt16(table[start + 1])
    }

    // The face a run was set in: one of those asked for, or the one CoreText fell back to, which a renderer must find
    // by its file.
    private func face(
        of run: CTRun,
        asked faces: [FontFace]
    ) throws -> FontFace {
        guard let value = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] else { return faces[0] }
        let font = value as! CTFont
        let name = CTFontCopyPostScriptName(font) as String
        if let asked = faces.first(where: { $0.name == name }) {
            return asked
        }
        guard let file = file(of: font) else { throw ShapingError.fallbackWithoutFile(name: name) }

        return self.face(of: font, file: file)
    }

    private func descriptors(in file: String) -> [CTFontDescriptor] {
        CTFontManagerCreateFontDescriptorsFromURL(URL(fileURLWithPath: file) as CFURL) as? [CTFontDescriptor] ?? []
    }

    private func descriptor(
        named name: String,
        in file: String
    ) -> CTFontDescriptor? {
        descriptors(in: file).first { descriptor in
            CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String == name
        }
    }

    private func isOfFamily(
        _ descriptor: CTFontDescriptor,
        _ family: String
    ) -> Bool {
        CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String == family
    }

    private func file(of font: CTFont) -> String? {
        (CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL)?.path
    }

    // Each face's descriptor carries the feature settings, so the faces of the cascade list are set with them too.
    private func font(
        of faces: [FontFace],
        size: Double,
        features: [FontFeature]
    ) throws -> CTFont {
        let settings = features.map { feature in
            [kCTFontOpenTypeFeatureTag: feature.tag, kCTFontOpenTypeFeatureValue: feature.value] as CFDictionary
        }
        let descriptors = try faces.map { face in
            guard let named = descriptor(named: face.name, in: face.file) else {
                throw ShapingError.faceNotInFile(file: face.file, name: face.name)
            }

            return CTFontDescriptorCreateCopyWithAttributes(
                named,
                [kCTFontFeatureSettingsAttribute: settings] as CFDictionary
            )
        }
        let first = CTFontDescriptorCreateCopyWithAttributes(
            descriptors[0],
            [kCTFontCascadeListAttribute: Array(descriptors.dropFirst())] as CFDictionary
        )

        return CTFontCreateWithFontDescriptor(first, size, nil)
    }

    // The index of the Unicode scalar each UTF-16 offset of `text` lies in.
    private func scalarIndices(of text: String) -> [Int] {
        text.unicodeScalars.enumerated().flatMap { index, scalar in
            Array(repeating: index, count: UTF16.width(scalar))
        }
    }
}

extension CoreTextShaper: ShapingProvider {
    // MARK: - Lifecycle
    // The family's faces may lie in several files, one weight each, so they are gathered from all of them.
    package func faces(
        family: String,
        in files: [String]
    ) -> [FontFace] {
        files.flatMap { file in
            descriptors(in: file)
                .filter { isOfFamily($0, family) }
                .map { face(of: CTFontCreateWithFontDescriptor($0, 1, nil), file: file) }
        }
    }

    package func face(
        named name: String,
        in file: String
    ) -> FontFace? {
        descriptor(named: name, in: file).map { face(of: CTFontCreateWithFontDescriptor($0, 1, nil), file: file) }
    }

    package func installedFaces(family: String) -> [FontFace] {
        let wanted = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let mandatory = Set([kCTFontFamilyNameAttribute as String]) as CFSet
        let matches = CTFontDescriptorCreateMatchingFontDescriptors(wanted, mandatory) as? [CTFontDescriptor] ?? []

        return matches.filter { isOfFamily($0, family) }.compactMap { descriptor in
            let font = CTFontCreateWithFontDescriptor(descriptor, 1, nil)
            return file(of: font).map { face(of: font, file: $0) }
        }
    }

    package func shape(
        _ text: String,
        faces: [FontFace],
        size: Double,
        features: [FontFeature],
        weight: FontWeight,
        italic: Bool
    ) throws -> [ShapedRun] {
        let font = try font(of: faces, size: size, features: features)
        var attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        // CoreText kerns by the font's `kern` table whatever the feature settings say, and a kern of 0 turns that off.
        if features.contains(FontFeature(tag: "kern", value: 0)) {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = 0
        }
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let scalars = scalarIndices(of: text)

        var runs: [ShapedRun] = []
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            var offsets = [CFIndex](repeating: 0, count: count)
            let all = CFRange(location: 0, length: count)
            CTRunGetGlyphs(run, all, &glyphs)
            CTRunGetAdvances(run, all, &advances)
            CTRunGetStringIndices(run, all, &offsets)

            let runFace = try self.face(of: run, asked: faces)
            let shaped = (0..<count).map { index in
                ShapedGlyph(
                    id: Int(glyphs[index]),
                    advance: Double(advances[index].width),
                    offset: scalars[offsets[index]]
                )
            }

            if let last = runs.last, last.face == runFace {
                runs[runs.count - 1] = ShapedRun(face: runFace, glyphs: last.glyphs + shaped)
            } else {
                runs.append(ShapedRun(face: runFace, glyphs: shaped))
            }
        }

        return runs
    }
}
