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
        let bitmap = try sut.bitmap(of: list(items: [DisplayItem(content: .glyphs(glyphs))]))

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
        let bitmap = try sut.bitmap(of: list(items: [DisplayItem(content: .glyphs(glyphs))]))

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
        let bitmap = try sut.bitmap(of: list(items: [DisplayItem(content: .glyphs(glyphs))]))

        // Then
        let row = Int(bounds.midY)
        #expect(bitmap.pixel(x: Int(bounds.minX) - 2, y: row) == [0, 0, 1, 1])
        #expect(bitmap.pixel(x: Int(bounds.minX) + 40 - 2, y: row) == [0, 0, 0, 0])
        #expect(bitmap.pixel(x: Int(bounds.midX) + 40, y: row) == [1, 0, 0, 1])
    }

    @Test("two parts of a highlight cut at a band's end inside a pixel draw every pixel as the whole piece does")
    func splitsPieceAtPixel() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let piece = Rectangle(x: 10, y: 20.5, width: 80, height: 40)
        let part = { (band: ClosedRange<Double>?) in
            DisplayItem(content: .glyphs(GlyphsItem(
                size: Size(width: 100, height: 100),
                runs: [self.highlighted(piece, band: band)],
                background: nil
            )))
        }

        // When
        let parts = try sut.bitmap(of: list(items: [part(10...50.4), part(50.4...90)]))
        let whole = try sut.bitmap(of: list(items: [part(nil)]))

        // Then
        // The rows at 20 and 60 are half covered, so a pixel either part drew again would be darker there.
        for y in [20, 40, 60] {
            for x in 48..<53 {
                #expect(parts.pixel(x: x, y: y) == whole.pixel(x: x, y: y), "at (\(x), \(y))")
            }
        }
    }

    @Test("a sideways run's glyph is drawn turned 90 degrees clockwise about its origin, its fill and its stroke alike")
    func turnsSidewaysGlyph() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let (glyph, ink) = try ink(of: "I")
        let origin = CGPoint(x: 30, y: 20)
        let turned = CGRect(x: origin.x + ink.minY, y: origin.y + ink.minX, width: ink.height, height: ink.width)
        let stroke = TextStroke(width: 6, color: Color(written: "#0000FF"))
        let item = { (stroke: TextStroke?) in
            DisplayItem(content: .glyphs(GlyphsItem(
                size: Size(width: 100, height: 100),
                writingMode: .verticalRightToLeft,
                runs: [self.run(glyph: glyph, at: origin, isSideways: true, stroke: stroke)],
                background: nil
            )))
        }

        // When
        let filled = try sut.bitmap(of: list(items: [item(nil)]))
        let stroked = try sut.bitmap(of: list(items: [item(stroke)]))

        // Then
        #expect(filled.pixel(x: Int(turned.midX), y: Int(turned.midY)) == [1, 0, 0, 1])
        #expect(stroked.pixel(x: Int(turned.minX) - 2, y: Int(turned.midY)) == [0, 0, 1, 1])
        let grown = turned.insetBy(dx: -1, dy: -1)
        let reach = turned.insetBy(dx: -4, dy: -4)
        var outside = (filled: 0, stroked: 0)
        for y in 0..<100 {
            for x in 0..<100 {
                let pixel = CGRect(x: x, y: y, width: 1, height: 1)
                outside.filled += !grown.intersects(pixel) && filled.pixel(x: x, y: y)[3] > 0 ? 1 : 0
                outside.stroked += !reach.intersects(pixel) && stroked.pixel(x: x, y: y)[3] > 0 ? 1 : 0
            }
        }
        #expect(outside.filled == 0)
        #expect(outside.stroked == 0)
    }

    @Test("a narrowed run's glyph is drawn narrowed about its origin along its own horizontal axis, its ink half as wide at a scale of 0.5")
    func narrowsGlyph() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let (glyph, ink) = try ink(of: "H")
        let origin = CGPoint(x: 20, y: 60)
        let item = { (horizontalScale: Double) in
            DisplayItem(content: .glyphs(GlyphsItem(
                size: Size(width: 100, height: 100),
                runs: [self.run(glyph: glyph, at: origin, isSideways: false, horizontalScale: horizontalScale, stroke: nil)],
                background: nil
            )))
        }

        // When
        let whole = inked(try sut.bitmap(of: list(items: [item(1)])))
        let narrowed = inked(try sut.bitmap(of: list(items: [item(0.5)])))

        // Then
        #expect(abs(whole.minX - (origin.x + ink.minX)) <= 1)
        #expect(abs(whole.maxX - (origin.x + ink.maxX)) <= 1)
        #expect(abs(narrowed.minX - (origin.x + ink.minX * 0.5)) <= 1)
        #expect(abs(narrowed.maxX - (origin.x + ink.maxX * 0.5)) <= 1)
        #expect(abs(narrowed.width - whole.width * 0.5) <= 1)
        #expect(narrowed.minY == whole.minY)
        #expect(narrowed.maxY == whole.maxY)
    }

    @Test("a narrowed sideways run's glyph is narrowed along its own horizontal axis before it is turned, so its ink is half as long down the item")
    func narrowsSidewaysGlyphBeforeTurn() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let (glyph, ink) = try ink(of: "H")
        let origin = CGPoint(x: 40, y: 10)
        let item = { (horizontalScale: Double) in
            DisplayItem(content: .glyphs(GlyphsItem(
                size: Size(width: 100, height: 100),
                writingMode: .verticalRightToLeft,
                runs: [self.run(glyph: glyph, at: origin, isSideways: true, horizontalScale: horizontalScale, stroke: nil)],
                background: nil
            )))
        }

        // When
        let whole = inked(try sut.bitmap(of: list(items: [item(1)])))
        let narrowed = inked(try sut.bitmap(of: list(items: [item(0.5)])))

        // Then
        #expect(abs(narrowed.minY - (origin.y + ink.minX * 0.5)) <= 1)
        #expect(abs(narrowed.maxY - (origin.y + ink.maxX * 0.5)) <= 1)
        #expect(abs(narrowed.height - whole.height * 0.5) <= 1)
        #expect(abs(narrowed.minX - (origin.x + ink.minY)) <= 1)
        #expect(abs(narrowed.maxX - (origin.x + ink.maxY)) <= 1)
        #expect(narrowed.minX == whole.minX)
        #expect(narrowed.maxX == whole.maxX)
    }

    @Test("a narrowed glyph's stroke is drawn at the run's full width on the narrowed outline, reaching half the width past its ink on every side")
    func strokesNarrowedGlyphAtFullWidth() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let (glyph, _) = try ink(of: "H")
        let origin = CGPoint(x: 30, y: 60)
        let stroke = TextStroke(width: 10, color: Color(written: "#0000FF"))
        let item = { (stroke: TextStroke?) in
            DisplayItem(content: .glyphs(GlyphsItem(
                size: Size(width: 100, height: 100),
                runs: [self.run(glyph: glyph, at: origin, isSideways: false, horizontalScale: 0.5, stroke: stroke)],
                background: nil
            )))
        }

        // When
        let filled = inked(try sut.bitmap(of: list(items: [item(nil)])))
        let stroked = inked(try sut.bitmap(of: list(items: [item(stroke)])))

        // Then
        #expect(abs((filled.minX - stroked.minX) - stroke.width / 2) <= 1)
        #expect(abs((stroked.maxX - filled.maxX) - stroke.width / 2) <= 1)
        #expect(abs((filled.minY - stroked.minY) - stroke.width / 2) <= 1)
        #expect(abs((stroked.maxY - filled.maxY) - stroke.width / 2) <= 1)
    }

    @Test("in a vertical item a band cuts its piece across y, and two parts cut inside a pixel draw it as the whole piece")
    func cutsVerticalPieceAlongY() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let piece = Rectangle(x: 20.5, y: 10, width: 40, height: 80)
        let part = { (band: ClosedRange<Double>?) in
            DisplayItem(content: .glyphs(GlyphsItem(
                size: Size(width: 100, height: 100),
                writingMode: .verticalRightToLeft,
                runs: [self.highlighted(piece, band: band)],
                background: nil
            )))
        }

        // When
        let upper = try sut.bitmap(of: list(items: [part(10...50.4)]))
        let parts = try sut.bitmap(of: list(items: [part(10...50.4), part(50.4...90)]))
        let whole = try sut.bitmap(of: list(items: [part(nil)]))

        // Then
        #expect(upper.pixel(x: 40, y: 30) == [0, 0, 1, 1])
        #expect(upper.pixel(x: 40, y: 70)[3] == 0)
        // The columns at 20 and 60 are half covered, so a pixel either part drew again would be darker there.
        for x in [20, 40, 60] {
            for y in 48..<53 {
                #expect(parts.pixel(x: x, y: y) == whole.pixel(x: x, y: y), "at (\(x), \(y))")
            }
        }
    }

    @Test("a face the font file does not hold is refused, naming both")
    func refusesMissingFace() throws {
        // Given
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())
        let run = DrawnGlyphRun(
            font: PinnedFile(path: Self.file, sha256: ""),
            face: "Helvetica-Missing",
            size: Self.size,
            color: Color(written: "#FF0000"),
            stroke: nil,
            highlight: nil,
            underline: nil,
            glyphs: [PositionedGlyph(id: 1, x: 0, y: 0)]
        )
        let glyphs = GlyphsItem(size: Size(width: 100, height: 100), runs: [run], background: nil)

        // When
        let drawing = { try sut.bitmap(of: list(items: [DisplayItem(content: .glyphs(glyphs))])) }

        // Then
        #expect(throws: QuartzError.faceNotInFile(file: Self.file, face: "Helvetica-Missing")) { try drawing() }
    }

    // MARK: - Private
    // The smallest rectangle of whole pixels that holds every pixel `bitmap` inks.
    private func inked(_ bitmap: Bitmap) -> CGRect {
        var inked = CGRect.null
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width where bitmap.pixel(x: x, y: y)[3] > 0 {
                inked = inked.union(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        return inked
    }

    private func list(items: [DisplayItem]) -> DisplayList {
        DisplayList(size: Size(width: 100, height: 100), background: Color(written: "#00000000"), seed: 0, items: items)
    }

    private func run(
        glyph: CGGlyph,
        x: Double = Self.baseline.x,
        stroke: TextStroke? = nil
    ) -> DrawnGlyphRun {
        DrawnGlyphRun(
            font: PinnedFile(path: Self.file, sha256: ""),
            face: Self.face,
            size: Self.size,
            color: Color(written: "#FF0000"),
            stroke: stroke,
            highlight: nil,
            underline: nil,
            glyphs: [PositionedGlyph(id: Int(glyph), x: x, y: Self.baseline.y)]
        )
    }

    private func run(
        glyph: CGGlyph,
        at origin: CGPoint,
        isSideways: Bool,
        horizontalScale: Double = 1,
        stroke: TextStroke?
    ) -> DrawnGlyphRun {
        DrawnGlyphRun(
            font: PinnedFile(path: Self.file, sha256: ""),
            face: Self.face,
            size: Self.size,
            isSideways: isSideways,
            horizontalScale: horizontalScale,
            color: Color(written: "#FF0000"),
            stroke: stroke,
            highlight: nil,
            underline: nil,
            glyphs: [PositionedGlyph(id: Int(glyph), x: origin.x, y: origin.y)]
        )
    }

    // A run with no glyphs and one highlight piece, cut to `band` when there is one.
    private func highlighted(
        _ piece: Rectangle,
        band: ClosedRange<Double>?
    ) -> DrawnGlyphRun {
        DrawnGlyphRun(
            font: PinnedFile(path: Self.file, sha256: ""),
            face: Self.face,
            size: Self.size,
            color: Color(written: "#FF0000"),
            stroke: nil,
            highlight: DrawnHighlight(
                rects: [piece],
                radius: 0,
                color: Color(written: "#0000FF"),
                bands: band.map { [$0] }
            ),
            underline: nil,
            glyphs: []
        )
    }

    // The glyph of "I" in the face and its ink bounds in the output, y down from the baseline origin.
    private func letterI() throws -> (glyph: CGGlyph, bounds: CGRect) {
        let (glyph, ink) = try ink(of: "I")

        let bounds = CGRect(
            x: Self.baseline.x + ink.minX,
            y: Self.baseline.y - ink.maxY,
            width: ink.width,
            height: ink.height
        )
        return (glyph, bounds)
    }

    // The glyph of `letter` in the face and its ink bounds in its own space, y up from its origin.
    private func ink(of letter: Unicode.Scalar) throws -> (glyph: CGGlyph, ink: CGRect) {
        let font = try FontLibrary().font(file: Self.file, face: Self.face, size: Self.size)
        var character = UniChar(letter.value)
        var glyph = CGGlyph(0)
        CTFontGetGlyphsForCharacters(font, &character, &glyph, 1)
        var ink = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .default, &glyph, &ink, 1)

        return (glyph, ink)
    }
}
