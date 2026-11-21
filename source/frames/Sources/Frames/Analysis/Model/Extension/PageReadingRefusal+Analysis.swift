//
//  PageReadingRefusal+Analysis.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

extension PageReadingRefusal {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The stop of a command that reads `page` of the PDF at `file` as a page is not, naming its `--color-space`. A
    // command reads no `toneMap`, so a page refuses only its colour space here.
    func error(
        file: String,
        page: Int
    ) -> AnalysisError {
        switch self {
        case .toneMap:
            preconditionFailure("a page refuses a toneMap only where one is read")

        case let .colorSpace(refused):
            return AnalysisError.highDynamicRangePage(file: file, page: page, colorSpace: refused)
        }
    }

    // MARK: - Private
}
