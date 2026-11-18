//
//  GlyphDrawerTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import CoreText
import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import Testing

@Suite("GlyphDrawer Tests")
struct GlyphDrawerTests {
    // MARK: - Property
    // A collection file, its bold face named by its PostScript name as the `coretext` shaper names it.
    private static let file = "/System/Library/Fonts/Helvetica.ttc"
    private static let face = "Helvetica-Bold"
    private static let size = 48.0
    private static let baseline = CGPoint(x: 20, y: 60)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a run's glyph is drawn from its file and face at its baseline origin, inking only its bounds")
    func drawsGlyphAtPosition() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let (glyph, bounds) = try letterI()
        let glyphs = GlyphsItem(
            size: Size(width: 100, height: 100),
            runs: [run(glyph: glyph)],
            background: nil
        )

        // When
        let bitmap = try sut.frame(of: list(items: [DisplayItem(content: .glyphs(glyphs))]))

        // Then
        #expect(bitmap.pixel(x: Int(bounds.midX), y: Int(bounds.midY)) == [1, 0, 0, 1])
        let grown = bounds.insetBy(dx: -1, dy: -1)
        var outside = 0
        for y in 0..<100 {
            for x in 0..<100 where !grown.intersects(CGRect(x: x, y: y, width: 1, height: 1)) {
                outside += bitmap.pixel(x: x, y: y)[3] > 0 ? 1 : 0
            }
        }
        #expect(outside == 0)
    }

    @Test("the stroke is drawn below the glyph fills, centred on the outline, over the background")
    func drawsStrokeUnderFill() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let (glyph, bounds) = try letterI()
        let glyphs = GlyphsItem(
            size: Size(width: 100, height: 100),
            runs: [run(glyph: glyph, stroke: TextStroke(width: 6, color: Color(written: "#0000FF")))],
            background: GlyphBackground(
                rectangle: Rectangle(x: 0, y: 0, width: 100, height: 100),
                radius: 0,
                color: Color(written: "#00FF00")
            )
        )

        // When
        let bitmap = try sut.frame(of: list(items: [DisplayItem(content: .glyphs(glyphs))]))

        // Then
        // The stroke reaches 3 out from the outline and 3 in, where the fill covers it.
        let row = Int(bounds.midY)
        #expect(bitmap.pixel(x: Int(bounds.minX) + 1, y: row) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: Int(bounds.midX), y: row) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: Int(bounds.minX) - 2, y: row) == [0, 0, 1, 1])
        #expect(bitmap.pixel(x: 2, y: 2) == [0, 1, 0, 1])
    }

    @Test("each run is stroked in its own stroke, and a run without one draws no outline")
    func strokesEachRunInItsOwn() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let (glyph, bounds) = try letterI()
        let stroked = run(glyph: glyph, stroke: TextStroke(width: 6, color: Color(written: "#0000FF")))
        let plain = run(glyph: glyph, x: Self.baseline.x + 40)
        let glyphs = GlyphsItem(size: Size(width: 100, height: 100), runs: [stroked, plain], background: nil)

        // When
        let bitmap = try sut.frame(of: list(items: [DisplayItem(content: .glyphs(glyphs))]))

        // Then
        let row = Int(bounds.midY)
        #expect(bitmap.pixel(x: Int(bounds.minX) - 2, y: row) == [0, 0, 1, 1])
        #expect(bitmap.pixel(x: Int(bounds.minX) + 40 - 2, y: row) == [0, 0, 0, 0])
        #expect(bitmap.pixel(x: Int(bounds.midX) + 40, y: row) == [1, 0, 0, 1])
    }

    @Test("a face the font file does not hold is refused, naming both")
    func refusesMissingFace() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let run = ResolvedGlyphRun(
            font: PinnedFile(path: Self.file, sha256: ""),
            face: "Helvetica-Missing",
            size: Self.size,
            color: Color(written: "#FF0000"),
            stroke: nil,
            glyphs: [PositionedGlyph(id: 1, x: 0, y: 0)]
        )
        let glyphs = GlyphsItem(size: Size(width: 100, height: 100), runs: [run], background: nil)

        // When
        let drawing = { try sut.frame(of: list(items: [DisplayItem(content: .glyphs(glyphs))])) }

        // Then
        #expect(throws: QuartzError.faceNotInFile(file: Self.file, face: "Helvetica-Missing")) { try drawing() }
    }

    // MARK: - Private
    private func list(items: [DisplayItem]) -> DisplayList {
        DisplayList(size: Size(width: 100, height: 100), background: Color(written: "#00000000"), seed: 0, items: items)
    }

    private func run(
        glyph: CGGlyph,
        x: Double = Self.baseline.x,
        stroke: TextStroke? = nil
    ) -> ResolvedGlyphRun {
        ResolvedGlyphRun(
            font: PinnedFile(path: Self.file, sha256: ""),
            face: Self.face,
            size: Self.size,
            color: Color(written: "#FF0000"),
            stroke: stroke,
            glyphs: [PositionedGlyph(id: Int(glyph), x: x, y: Self.baseline.y)]
        )
    }

    // The glyph of "I" in the face and its ink bounds in the output, y down from the baseline origin.
    private func letterI() throws -> (glyph: CGGlyph, bounds: CGRect) {
        let font = try FontLibrary().font(file: Self.file, face: Self.face, size: Self.size)
        var character = UniChar(UInt8(ascii: "I"))
        var glyph = CGGlyph(0)
        CTFontGetGlyphsForCharacters(font, &character, &glyph, 1)
        var ink = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .default, &glyph, &ink, 1)

        let bounds = CGRect(
            x: Self.baseline.x + ink.minX,
            y: Self.baseline.y - ink.maxY,
            width: ink.width,
            height: ink.height
        )
        return (glyph, bounds)
    }
}
