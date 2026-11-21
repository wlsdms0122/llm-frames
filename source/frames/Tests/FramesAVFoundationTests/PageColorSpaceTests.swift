//
//  PageColorSpaceTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

// A page's colour spaces read from what the PDF writes, and their formulas on values a tint transform gives.
@Suite("PageColorSpace Tests")
struct PageColorSpaceTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a Lab space whose Range holds a number that is not finite, or a lower end above its upper, is malformed",
        arguments: [
            [PDFValue.real(-.infinity), .real(.infinity), .integer(-100), .integer(100)],
            [.integer(-100), .integer(100), .real(.nan), .integer(100)],
            [.integer(-100), .integer(100), .integer(100), .integer(-100)],
            [.integer(-100), .integer(100)]
        ]
    )
    func refusesLabRange(range: [PDFValue]) {
        // Given
        let value = PDFValue.array([.name("Lab"), .dictionary(["Range": .array(range)])])

        // When
        let sut = PageColorSpace(value)

        // Then
        #expect(
            sut == .malformed("a Lab space whose Range is not four finite numbers, each pair's lower end at most its upper")
        )
    }

    @Test("an Indexed space gives no colour for an index that is not finite, and the colour of its last entry past it")
    func clampsIndexedIndex() {
        // Given
        let sut = PageColorSpace.indexed(base: .deviceRGB, highValue: 1, lookup: [255, 0, 0, 0, 255, 0])

        // When
        let infinite = sut.linear([.infinity])
        let missing = sut.linear([.nan])
        let past = sut.linear([1e300])

        // Then
        #expect(infinite == nil)
        #expect(missing == nil)
        #expect(past == RGB(red: 0, green: 1, blue: 0))
    }
}
