//
//  PageGraphicsState.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics

// The part of a page's graphics state (ISO 32000-1 8.4) that decides what drawn content paints in and sets glyphs in:
// the fill and stroke colour spaces, the pattern each paints with where its space is a Pattern space, the font, and
// the text rendering mode. A content stream starts in DeviceGray with mode 0.
struct PageGraphicsState {
    // MARK: - Property
    var fill: PDFValue = .name("DeviceGray")
    var stroke: PDFValue = .name("DeviceGray")
    var fillPattern: CGPDFObjectRef?
    var strokePattern: CGPDFObjectRef?
    var font: CGPDFDictionaryRef?
    var fontName = ""
    var renderMode = 0

    // Whether text sets glyphs: mode 3 sets none.
    var setsGlyphs: Bool {
        renderMode != 3
    }

    // Whether text fills and strokes its glyphs, by its mode: 0, 2, 4 and 6 fill, and 1, 2, 5 and 6 stroke.
    var textFills: Bool {
        [0, 2, 4, 6].contains(renderMode)
    }

    var textStrokes: Bool {
        [1, 2, 5, 6].contains(renderMode)
    }

    // MARK: - Initializer
    init() {}

    // MARK: - Public
    // MARK: - Private
}
