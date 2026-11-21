//
//  PageChoiceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/22/26.
//

@testable import Frames
import Testing

@Suite("Page Choice Tests")
struct PageChoiceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "the page written is named, or with none the one page of a PDF of one page, and a PDF of no pages names none",
        arguments: [
            (Int?(3), 12, PageChoice.page(3)),
            (nil, 1, .page(1)),
            (nil, 12, .unnamed(pageCount: 12)),
            (13, 12, .missing(page: 13, pageCount: 12)),
            (nil, 0, .empty),
            (1, 0, .empty)
        ]
    )
    func choosesPage(page: Int?, pageCount: Int, expected: PageChoice) {
        // Given
        // When
        let sut = PageChoice(page: page, pageCount: pageCount)

        // Then
        #expect(sut == expected)
    }

    // MARK: - Private
}
