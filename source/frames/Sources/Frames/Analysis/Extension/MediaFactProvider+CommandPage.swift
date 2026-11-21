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
    // The page of `path` that `page` names, or where none is named the one page of a PDF of one page (FRAMES-23). A
    // page above the page count, a page of a file that is no PDF and a PDF of no pages stop, and so does a page of a
    // file that is not there.
    func commandPage(
        _ page: Int?,
        of path: String
    ) throws -> CommandPage {
        guard let pageCount = try pageCount(of: path) else {
            guard let page else { return .notPDF }
            guard try probedMedia(of: path) != nil else { throw AnalysisError.missingMedia(file: path) }

            throw AnalysisError.pageOfNonPDF(file: path, page: page)
        }
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
    }

    // The page `page` names of `path`, after its decoder's checks, with its size. A PDF of more than one page with no
    // page named stops, naming the page count, since the caller would choose the picture.
    func namedPage(
        _ page: Int?,
        of path: String
    ) throws -> (number: Int, page: ProbedPage)? {
        switch try commandPage(page, of: path) {
        case let .page(number):
            guard let probed = try probedPage(number, of: path) else { throw AnalysisError.missingMedia(file: path) }

            return (number, probed)

        case let .unnamed(pageCount):
            throw AnalysisError.unnamedPage(file: path, pageCount: pageCount)

        case .notPDF:
            return nil
        }
    }

    // MARK: - Private
}
