//
//  PageContent.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

// What a page of a PDF draws, as far as the decoder's checks read it (FRAMES-3 PDF pages): the first font drawn text
// that sets glyphs is set in that the file does not embed, nil where there is none, and whether the page draws in no
// colour space but its untagged colour.
struct PageContent: Equatable, Sendable {
    // MARK: - Property
    let unembeddedFont: String?
    let drawsOnlyUntaggedColor: Bool

    // MARK: - Initializer
    init(
        unembeddedFont: String?,
        drawsOnlyUntaggedColor: Bool
    ) {
        self.unembeddedFont = unembeddedFont
        self.drawsOnlyUntaggedColor = drawsOnlyUntaggedColor
    }

    // MARK: - Public
    // MARK: - Private
}
