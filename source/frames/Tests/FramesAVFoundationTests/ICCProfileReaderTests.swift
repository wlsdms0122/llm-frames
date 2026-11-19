//
//  ICCProfileReaderTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/20/26.
//

import Foundation
@testable import FramesAVFoundation
import Testing

// The colour of an ICC profile built byte by byte: a 128-byte header naming the data colour space at byte 16, the tag
// count at 128 and one tag entry (signature, offset, size) after it.
@Suite("ICCProfileReader Tests")
struct ICCProfileReaderTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a grey profile's curv of one entry reads as its gamma")
    func readsGammaCurve() {
        // Given
        let sut = ICCProfileReader(data: Data(greyProfile(curve: curv(count: 1) + [0x02, 0x33])))

        // When
        let color = sut.color()

        // Then
        #expect((try? color.get()) != nil)
    }

    @Test("a curv that claims more entries than the profile holds reads as no colour a formula converts, at once")
    func refusesShortCurve() {
        // Given
        let sut = ICCProfileReader(data: Data(greyProfile(curve: curv(count: 0xFFFF_FFFF) + [0x02, 0x33])))

        // When
        let color = sut.color()

        // Then
        #expect(color == .failure(.lookupTableProfile))
    }

    // MARK: - Private
    // A `GRAY` profile whose one tag, `kTRC`, is `curve`, put right after the tag table.
    private func greyProfile(curve: [UInt8]) -> [UInt8] {
        var header = [UInt8](repeating: 0, count: 128)
        header.replaceSubrange(16..<20, with: Array("GRAY".utf8))
        let tagOffset = 128 + 4 + 12

        return header + bigEndian(1) + Array("kTRC".utf8) + bigEndian(tagOffset) + bigEndian(curve.count) + curve
    }

    // A `curv` element's type, reserved bytes and entry count, without its entries.
    private func curv(count: Int) -> [UInt8] {
        Array("curv".utf8) + [0, 0, 0, 0] + bigEndian(count)
    }

    private func bigEndian(_ value: Int) -> [UInt8] {
        (0..<4).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    }
}
