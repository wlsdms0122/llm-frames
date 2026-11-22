//
//  PageGraphicsState.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics

// The part of a page's graphics state (ISO 32000-1 8.4) that decides which font text sets glyphs in: the font, its
// name, and the text rendering mode. A content stream starts in mode 0.
struct PageGraphicsState: Hashable {
    // MARK: - Property
    var font: CGPDFDictionaryRef?
    var fontName = ""
    var renderMode = 0

    // Whether text sets glyphs: mode 3 sets none.
    var setsGlyphs: Bool {
        renderMode != 3
    }

    // MARK: - Initializer
    init() {}

    // MARK: - Public
    // MARK: - Private
}
