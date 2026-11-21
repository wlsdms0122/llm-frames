//
//  MediaFactProvider+CommandPage.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

extension MediaFactProvider {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The page of `path` that `page` names, or where none is named the one page of a PDF of one page (FRAMES-23), or
    // the media `path` is where it is no PDF and names no page. Nil where the file is not there. A page above the page
    // count, a page of a file that is no PDF and a PDF of no pages stop.
    func commandPage(
        _ page: Int?,
        of path: String
    ) throws -> CommandPage? {
        switch try probedMedium(of: path) {
        case let .pdf(pageCount):
            switch PageChoice(page: page, pageCount: pageCount) {
            case let .page(number):
                return .page(number: number)

            case let .unnamed(pageCount):
                return .unnamed(pageCount: pageCount)

            case let .missing(page, pageCount):
                throw AnalysisError.missingPage(file: path, page: page, pageCount: pageCount)

            case .empty:
                throw AnalysisError.unreadableMedia(file: path, reason: PageChoice.emptyReason)
            }

        case let .media(probed):
            guard let page else { return .media(probed) }

            throw AnalysisError.pageOfNonPDF(file: path, page: page)

        case nil:
            return nil
        }
    }

    // MARK: - Private
}
