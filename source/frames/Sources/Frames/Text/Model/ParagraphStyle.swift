//
//  ParagraphStyle.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A theme style's paragraph attributes as resolve lays a title out in them, which only the clip's style gives: lengths
// in output pixels, already multiplied by the length scale of the place the text is drawn. `lines` is the most lines
// the text may take, and nil is no limit.
struct ParagraphStyle: Equatable, Sendable {
    // MARK: - Property
    let lineHeight: Double
    let background: TextBackground?
    let align: TextAlignment
    let lines: Int?

    // MARK: - Initializer
    init(
        lineHeight: Double,
        background: TextBackground?,
        align: TextAlignment,
        lines: Int?
    ) {
        self.lineHeight = lineHeight
        self.background = background
        self.align = align
        self.lines = lines
    }

    // MARK: - Public
    // MARK: - Private
}
