//
//  CoreTextShaper.swift
//  FramesCoreText
//
//  Created by JSilver on 11/16/26.
//

import CoreText
import Foundation
import Frames

// The `coretext` shaping provider. A face is named by its PostScript name within its file. Runs are set as a CoreText
// line sets them by default, kerned and with standard ligatures, and characters the face lacks fall back to the face
// CoreText's cascade list finds on the machine.
package struct CoreTextShaper: Sendable {
    // MARK: - Property
    // The weight traits CoreText gives regular and bold faces, which the closest face of a family is chosen by.
    private static let regularWeight = 0.0
    private static let boldWeight = 0.4

    // A face's distance from normal width, 1 when it is italic, since upright is asked for, its distance from the
    // weight asked for, and its PostScript name.
    private typealias Rank = (width: Double, style: Int, weight: Double, name: String)

    // MARK: - Initializer
    package init() {}

    // MARK: - Public
    // MARK: - Private
    // The face of the family as CSS font matching narrows it: the width closest to normal, then upright, then the
    // weight closest to the one asked for. Ties go to the PostScript name, so the same family always gives the same
    // face whatever order CoreText lists them in.
    private func closest(
        among descriptors: [CTFontDescriptor],
        family: String,
        weight: FontWeight
    ) -> CTFontDescriptor? {
        let target = weight == .bold ? Self.boldWeight : Self.regularWeight
        let candidates = descriptors.compactMap { descriptor -> (descriptor: CTFontDescriptor, rank: Rank)? in
            guard
                CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String == family,
                let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String,
                let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [CFString: Any]
            else {
                return nil
            }
            let symbolic = CTFontSymbolicTraits(rawValue: traits[kCTFontSymbolicTrait] as? UInt32 ?? 0)
            let width = traits[kCTFontWidthTrait] as? Double ?? 0
            let faceWeight = traits[kCTFontWeightTrait] as? Double ?? 0

            return (descriptor, (abs(width), symbolic.contains(.traitItalic) ? 1 : 0, abs(faceWeight - target), name))
        }

        return candidates.min { $0.rank < $1.rank }?.descriptor
    }

    private func face(
        of font: CTFont,
        file: String
    ) -> FontFace {
        let unit = CTFontCreateCopyWithAttributes(font, 1, nil, nil)

        return FontFace(
            file: file,
            name: CTFontCopyPostScriptName(font) as String,
            ascent: Double(CTFontGetAscent(unit)),
            descent: Double(CTFontGetDescent(unit))
        )
    }

    // The face a run was set in: the one asked for, or the one CoreText fell back to, which a renderer must find by
    // its file.
    private func face(
        of run: CTRun,
        asked face: FontFace
    ) throws -> FontFace {
        guard let value = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] else { return face }
        let font = value as! CTFont
        guard CTFontCopyPostScriptName(font) as String != face.name else { return face }
        guard let file = file(of: font) else {
            throw ShapingError.fallbackWithoutFile(name: CTFontCopyPostScriptName(font) as String)
        }

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

    private func file(of font: CTFont) -> String? {
        (CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL)?.path
    }

    // The face's font at `size`, read from its own file.
    private func font(
        of face: FontFace,
        size: Double
    ) throws -> CTFont {
        guard let named = descriptor(named: face.name, in: face.file) else { throw ShapingError.faceNotInFile(file: face.file, name: face.name) }

        return CTFontCreateWithFontDescriptor(named, size, nil)
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
    package func face(
        family: String,
        weight: FontWeight,
        in files: [String]
    ) -> FontFace? {
        // The family's faces may lie in several files, one weight each, so the face is chosen among all of them.
        let found = files.flatMap { file in descriptors(in: file).map { (file: file, descriptor: $0) } }
        guard
            let descriptor = closest(among: found.map(\.descriptor), family: family, weight: weight),
            let file = found.first(where: { $0.descriptor === descriptor })?.file
        else {
            return nil
        }

        return face(of: CTFontCreateWithFontDescriptor(descriptor, 1, nil), file: file)
    }

    package func face(
        named name: String,
        in file: String
    ) -> FontFace? {
        descriptor(named: name, in: file).map { face(of: CTFontCreateWithFontDescriptor($0, 1, nil), file: file) }
    }

    package func installedFace(
        family: String,
        weight: FontWeight
    ) -> FontFace? {
        let wanted = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let mandatory = Set([kCTFontFamilyNameAttribute as String]) as CFSet
        let matches = CTFontDescriptorCreateMatchingFontDescriptors(wanted, mandatory) as? [CTFontDescriptor] ?? []
        guard let descriptor = closest(among: matches, family: family, weight: weight) else { return nil }
        let font = CTFontCreateWithFontDescriptor(descriptor, 1, nil)

        return file(of: font).map { face(of: font, file: $0) }
    }

    package func shape(
        _ text: String,
        face: FontFace,
        size: Double
    ) throws -> [ShapedRun] {
        let font = try font(of: face, size: size)
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
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

            let runFace = try self.face(of: run, asked: face)
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
