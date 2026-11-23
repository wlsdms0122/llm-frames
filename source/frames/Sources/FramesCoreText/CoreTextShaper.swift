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
// style are read from its OS/2 table. Each grapheme cluster is set in the first face given that maps every scalar of it
// but its default ignorable ones, else in the face CoreText finds on the machine for it from the first face, which
// follows its weight and slant. Each stretch of clusters in one face is set as a CoreText line sets it, in that face
// alone, with the feature settings given over the font's defaults, and in the run's direction, which overrides every
// character's and is the line's base direction, so CoreText reorders nothing by a bidirectional pass of its own and
// sets trailing whitespace on the run's side. A right-to-left run's stretches are given from right to left, the order
// they lie in on the line. An upright run is set as a CoreText line sets vertical forms, which applies the font's
// `vert` and `vrt2` features together, and neither where both are 0, in its vertical metrics either way.
package struct CoreTextShaper: Sendable {
    // MARK: - Property
    // Offsets into the OS/2 table: `usWeightClass`, `usWidthClass` and `fsSelection`, whose bit 0 is italic and bit 9
    // oblique.
    private static let weightClassOffset = 4
    private static let widthClassOffset = 6
    private static let selectionOffset = 62
    private static let nonJoiner: Unicode.Scalar = "\u{200C}"

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
    // by its file. A fallback face is read from its file, since the font of a run CoreText set vertically has made-up
    // ascent and descent.
    private func face(
        of run: CTRun,
        asked faces: [FontFace]
    ) throws -> FontFace {
        guard let font = font(of: run) else { return faces[0] }
        let name = CTFontCopyPostScriptName(font) as String
        if let asked = faces.first(where: { $0.name == name }) {
            return asked
        }
        guard let file = file(of: font) else { throw ShapingError.fallbackWithoutFile(name: name) }

        return face(named: name, in: file) ?? self.face(of: font, file: file)
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

    private func font(
        of face: FontFace,
        size: Double,
        features: [FontFeature]
    ) throws -> CTFont {
        guard let named = descriptor(named: face.name, in: face.file) else {
            throw ShapingError.faceNotInFile(file: face.file, name: face.name)
        }
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(named, attributes(of: features))

        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    private func attributes(of features: [FontFeature]) -> CFDictionary {
        let settings = features.map { feature in
            [kCTFontOpenTypeFeatureTag: feature.tag, kCTFontOpenTypeFeatureValue: feature.value] as CFDictionary
        }

        return [kCTFontFeatureSettingsAttribute: settings] as CFDictionary
    }

    // The font a grapheme cluster is set in. Its default ignorable scalars take no part: a face maps them in a table
    // of its own or not at all.
    private func font(
        for cluster: Character,
        in fonts: [CTFont],
        features: [FontFeature]
    ) -> CTFont {
        let scalars = Array(cluster.unicodeScalars.filter { !$0.properties.isDefaultIgnorableCodePoint })
        if let font = fonts.first(where: { maps($0, scalars) }) {
            return font
        }
        let text = String(String.UnicodeScalarView(scalars)) as CFString
        let fallback = CTFontCreateForString(fonts[0], text, CFRange(location: 0, length: CFStringGetLength(text)))
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes(of: features))

        return CTFontCreateCopyWithAttributes(fallback, 0, nil, descriptor)
    }

    private func maps(
        _ font: CTFont,
        _ scalars: [Unicode.Scalar]
    ) -> Bool {
        let characters = scalars.flatMap { Array(String($0).utf16) }
        guard !characters.isEmpty else { return true }
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)

        return CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
    }

    // The clusters of `text` in stretches set in one font, each scalar with its index in `text`.
    private func stretches(
        of text: String,
        in fonts: [CTFont],
        features: [FontFeature]
    ) -> [(font: CTFont, scalars: [(index: Int, scalar: Unicode.Scalar)])] {
        var stretches: [(font: CTFont, scalars: [(index: Int, scalar: Unicode.Scalar)])] = []
        var start = 0
        for cluster in text {
            let font = font(for: cluster, in: fonts, features: features)
            let scalars = cluster.unicodeScalars.enumerated().map { (index: start + $0.offset, scalar: $0.element) }
            start += scalars.count

            if let last = stretches.last, name(of: last.font) == name(of: font) {
                stretches[stretches.count - 1].scalars += scalars
            } else {
                stretches.append((font: font, scalars: scalars))
            }
        }

        return stretches
    }

    private func name(of font: CTFont) -> String {
        CTFontCopyPostScriptName(font) as String
    }

    private func font(of run: CTRun) -> CTFont? {
        (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName].map { $0 as! CTFont }
    }

    // Whether CoreText set `run` in `font`.
    private func isSet(
        _ run: CTRun,
        in font: CTFont
    ) -> Bool {
        guard let set = self.font(of: run) else { return true }

        return name(of: set) == name(of: font)
    }

    private func hasVerticalMetrics(_ font: CTFont) -> Bool {
        CTFontCopyTable(font, CTFontTableTag(kCTFontTableVmtx), []) != nil
    }

    // An upright glyph of a face without a `vmtx` table in the vertical metrics FRAMES-5 makes from the face's ascent
    // and descent. CoreText sets such a glyph in metrics it makes up, which differ from face to face, so its vertical
    // advance and its move to the vertical origin are taken out of `glyph` and the made ones put in. The ascent and
    // descent are `face`'s, since those of a font CoreText set vertically are made up too.
    private func madeVertical(
        _ glyph: ShapedGlyph,
        id: CGGlyph,
        in font: CTFont,
        face: FontFace
    ) -> ShapedGlyph {
        var id = id
        var vertical = CGSize.zero
        var horizontal = CGSize.zero
        var translation = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .vertical, &id, &vertical, 1)
        CTFontGetAdvancesForGlyphs(font, .horizontal, &id, &horizontal, 1)
        CTFontGetVerticalTranslationsForGlyphs(font, &id, &translation, 1)
        let ascent = face.ascent * Double(CTFontGetSize(font))
        let descent = face.descent * Double(CTFontGetSize(font))

        return ShapedGlyph(
            id: glyph.id,
            advance: glyph.advance - Double(vertical.width) + ascent + descent,
            offset: glyph.offset,
            placementOffset: Point(
                x: glyph.placementOffset.x + Double(translation.height) + ascent,
                y: glyph.placementOffset.y + Double(translation.width) + Double(horizontal.width) / 2
            )
        )
    }

    // The scalars a stretch is set from: a default ignorable scalar the font maps neither as a character nor, for a
    // variation selector, in a variation sequence with the scalar before it is set as nothing, since CoreText would
    // set its cluster in a face that maps it. A zero width non-joiner is always set, since it keeps apart glyphs the
    // font would join, and CoreText sets one the font does not map alone in another face. A zero width joiner the font
    // does not map is not, since CoreText would set the scalars beside it in another face too.
    private func settable(
        _ scalars: [(index: Int, scalar: Unicode.Scalar)],
        in font: CTFont
    ) -> [(index: Int, scalar: Unicode.Scalar)] {
        var sequences: VariationSequenceTable?

        return scalars.indices.filter { position in
            let scalar = scalars[position].scalar
            guard scalar.properties.isDefaultIgnorableCodePoint, scalar != Self.nonJoiner, !maps(font, [scalar])
            else { return true }
            guard scalar.properties.isVariationSelector, position > 0 else { return false }
            let table = sequences ?? VariationSequenceTable(font: font)
            sequences = table

            return table.contains(base: scalars[position - 1].scalar, selector: scalar)
        }
        .map { scalars[$0] }
    }

    // Glyphs of one stretch in the order they lie on the line from left to right, as CoreText gives its runs and their
    // glyphs. `CTRunGetAdvances` is the distance from one glyph's drawn position to the next one's, a mark's attachment
    // included. Base advances leave out what the font's tables place relative to another glyph, so the pen moves by
    // them and a glyph's placement offset is its drawn position less the pen, with CoreText's y, which points up,
    // turned down. An upright run's advances are vertical, and its positions are its glyphs' origins in their upright
    // frame, y up, with the line running down from the vertical origin of its first glyph, so its pen runs along -y and
    // the line-under side is -x. A run CoreText sets in another face from default ignorable scalars alone, a non-joiner
    // the font does not map, is set as nothing. An override in the run's direction keeps CoreText from resolving levels
    // of its own, and at a right-to-left level it mirrors a `Bidi_Mirrored` character as rule L4 of UAX #9 asks. The
    // line's base direction is the run's too, since CoreText applies rule L1 to the line and would otherwise set its
    // trailing whitespace at the level its first strong character gives, or 0 without one, and place it on the wrong
    // side.
    private func shape(
        _ scalars: [(index: Int, scalar: Unicode.Scalar)],
        direction: TextDirection,
        upright: Bool,
        in font: CTFont,
        asked faces: [FontFace],
        features: [FontFeature]
    ) throws -> [ShapedRun] {
        var writing = direction == .rtl ? CTWritingDirection.rightToLeft : .leftToRight
        let paragraph = withUnsafeMutablePointer(to: &writing) { pointer in
            var setting = CTParagraphStyleSetting(
                spec: .baseWritingDirection,
                valueSize: MemoryLayout<CTWritingDirection>.size,
                value: pointer
            )

            return CTParagraphStyleCreate(&setting, 1)
        }
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
            NSAttributedString.Key(kCTWritingDirectionAttributeName as String): [
                NSNumber(value: Int(writing.rawValue) | kCTWritingDirectionOverride)
            ]
        ]
        // CoreText kerns by the font's `kern` table whatever the feature settings say, and a kern of 0 turns that off.
        if features.contains(FontFeature(tag: "kern", value: 0)) {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = 0
        }
        if upright {
            attributes[NSAttributedString.Key(kCTVerticalFormsAttributeName as String)] = true
        }
        let text = String(String.UnicodeScalarView(scalars.map(\.scalar)))
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let units = scalars.flatMap { Array(repeating: $0, count: UTF16.width($0.scalar)) }

        var runs: [ShapedRun] = []
        // CoreText hangs a line's trailing whitespace past its end, which at a right-to-left base lies before its
        // origin, so the pen starts there.
        var pen = direction == .rtl ? -CTLineGetTrailingWhitespaceWidth(line) : 0
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var offsets = [CFIndex](repeating: 0, count: count)
            let all = CFRange(location: 0, length: count)
            CTRunGetGlyphs(run, all, &glyphs)
            CTRunGetBaseAdvancesAndOrigins(run, all, &advances, nil)
            CTRunGetPositions(run, all, &positions)
            CTRunGetStringIndices(run, all, &offsets)
            let isIgnorable = offsets.allSatisfy { units[$0].scalar.properties.isDefaultIgnorableCodePoint }
            if isIgnorable && !isSet(run, in: font) {
                continue
            }
            let runFont = self.font(of: run) ?? font
            let runFace = try face(of: run, asked: faces)
            let isMadeVertical = upright && !hasVerticalMetrics(runFont)

            var shaped: [ShapedGlyph] = []
            for index in 0..<count {
                let position = positions[index]
                let glyph = ShapedGlyph(
                    id: Int(glyphs[index]),
                    advance: Double(advances[index].width),
                    offset: units[offsets[index]].index,
                    placementOffset: upright
                        ? Point(x: -Double(position.y) - pen, y: -Double(position.x))
                        : Point(x: Double(position.x) - pen, y: -Double(position.y))
                )
                shaped.append(
                    isMadeVertical ? madeVertical(glyph, id: glyphs[index], in: runFont, face: runFace) : glyph
                )
                pen += Double(advances[index].width)
            }
            runs.append(ShapedRun(face: runFace, glyphs: shaped))
        }

        return runs
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
        direction: TextDirection,
        upright: Bool,
        faces: [FontFace],
        size: Double,
        features: [FontFeature],
        weight: FontWeight,
        italic: Bool
    ) throws -> [ShapedRun] {
        let fonts = try faces.map { try font(of: $0, size: size, features: features) }

        let stretches = stretches(of: text, in: fonts, features: features)

        var runs: [ShapedRun] = []
        for stretch in direction == .rtl ? Array(stretches.reversed()) : stretches {
            let scalars = settable(stretch.scalars, in: stretch.font)
            let shaped = try shape(
                scalars,
                direction: direction,
                upright: upright,
                in: stretch.font,
                asked: faces,
                features: features
            )
            for run in shaped {
                if let last = runs.last, last.face == run.face {
                    runs[runs.count - 1] = ShapedRun(face: run.face, glyphs: last.glyphs + run.glyphs)
                } else {
                    runs.append(run)
                }
            }
        }

        return runs
    }
}
