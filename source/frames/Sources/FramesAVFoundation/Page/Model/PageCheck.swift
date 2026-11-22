//
//  PageCheck.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

// The decoder's checks of one page of a PDF: the first font it sets drawn text in that its file does not embed, the first colour space it draws in that this decoder does not convert by
// the fixed formulas, each nil where there is none, and whether it draws in no colour space but its untagged colour.
struct PageCheck: Equatable, Sendable {
    // MARK: - Property
    let font: PageFault?
    let color: PageFault?
    let drawsOnlyUntaggedColor: Bool

    // MARK: - Initializer
    init(
        font: PageFault?,
        color: PageFault?,
        drawsOnlyUntaggedColor: Bool
    ) {
        self.font = font
        self.color = color
        self.drawsOnlyUntaggedColor = drawsOnlyUntaggedColor
    }

    // MARK: - Public
    // MARK: - Private
}
