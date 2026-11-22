//
//  ParagraphStyle.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A theme style's paragraph attributes, which only the clip's style gives a title. Lengths are in output pixels,
// already multiplied by the length scale of the place the text is drawn. `writingMode` sets the lines horizontally or
// vertically, `direction` is nil for `auto`, which takes it from the text, and `align` nil where no layer gives it, which takes the side the text's direction starts from.
// `lines` is the most lines the text may take, nil for no limit.
struct ParagraphStyle: Equatable, Sendable {
    // MARK: - Property
    let lineHeight: Double
    let background: TextBackground?
    let writingMode: WritingMode
    let direction: TextDirection?
    let align: TextAlignment?
    let lines: Int?

    // MARK: - Initializer
    init(
        lineHeight: Double,
        background: TextBackground?,
        writingMode: WritingMode = .horizontalTopToBottom,
        direction: TextDirection? = nil,
        align: TextAlignment?,
        lines: Int?
    ) {
        self.lineHeight = lineHeight
        self.background = background
        self.writingMode = writingMode
        self.direction = direction
        self.align = align
        self.lines = lines
    }

    // MARK: - Public
    // MARK: - Private
}
