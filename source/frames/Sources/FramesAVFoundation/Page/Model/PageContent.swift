//
//  PageContent.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

// What a page of a PDF draws, as far as the decoder's checks read it (FRAMES-3 PDF pages): the faults found in drawing
// order, drawn text in a font the file does not embed and an image whose colour space only its codestream holds, and
// each colour space drawn content paints or blends in, once, in the order first met, a device space under a default
// space as that default space.
struct PageContent: Equatable {
    // MARK: - Property
    let faults: [PageFault]
    let colorSpaces: [PDFValue]

    // MARK: - Initializer
    init(
        faults: [PageFault],
        colorSpaces: [PDFValue]
    ) {
        self.faults = faults
        self.colorSpaces = colorSpaces
    }

    // MARK: - Public
    // MARK: - Private
}
