//
//  ProbedPage.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The probed facts of one page of a PDF that its decoder reads (FRAMES-3 PDF pages): its size in media pixels, which
// are points and may be fractions, its crop box turned by its `Rotate` and multiplied by its `UserUnit`, and the page
// count of its file. A page carries alpha and its untagged colour is `srgb` where no `colorSpace` is written, so neither
// is a probed fact.
package struct ProbedPage: Equatable, Sendable {
    // MARK: - Property
    package let size: Size
    package let pageCount: Int

    // MARK: - Initializer
    package init(
        size: Size,
        pageCount: Int
    ) {
        self.size = size
        self.pageCount = pageCount
    }

    // MARK: - Public
    // MARK: - Private
}
