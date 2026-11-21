//
//  PageChoice.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// Which page a reference names of a PDF of `pageCount` pages, by the page written, nil where none is (FRAMES-3 PDF
// pages, FRAMES-23): the page written, or where none is written the one page of a PDF of one page. A PDF of more pages
// with none written names more than one picture, a page above the count names none, and a PDF of no pages is media
// that cannot be read. A document's media, a preset's cover and matte and a command's `--page` choose here, and each
// stops in its own words.
enum PageChoice: Equatable, Sendable {
    case page(Int)
    case unnamed(pageCount: Int)
    case missing(page: Int, pageCount: Int)
    case empty

    // MARK: - Property
    // Why a PDF of no pages cannot be read.
    static let emptyReason = "it is a PDF of no pages"

    // MARK: - Initializer
    init(
        page: Int?,
        pageCount: Int
    ) {
        guard pageCount > 0 else {
            self = .empty
            return
        }
        guard let page else {
            self = pageCount == 1 ? .page(1) : .unnamed(pageCount: pageCount)
            return
        }

        self = page <= pageCount ? .page(page) : .missing(page: page, pageCount: pageCount)
    }

    // MARK: - Public
    // MARK: - Private
}
