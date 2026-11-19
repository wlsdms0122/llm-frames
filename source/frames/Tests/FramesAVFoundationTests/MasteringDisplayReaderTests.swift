//
//  MasteringDisplayReaderTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/20/26.
//

import Foundation
@testable import FramesAVFoundation
import Testing

// The maximum luminance of a still's mastering display, read from the SMPTE ST 2086 colour volume of a PNG's `mDCv`
// chunk or a HEIF file's `mdcv` item property.
@Suite("MasteringDisplayReader Tests")
struct MasteringDisplayReaderTests {
    // MARK: - Property
    // BT.2020 primaries and the D65 white in units of 0.00002, a maximum luminance of 4000 cd/m² and a minimum of
    // 0.005 cd/m² in units of 0.0001.
    private static let volume = [35_400, 14_600, 8500, 39_850, 6550, 2300, 15_635, 16_450].flatMap { bigEndian($0, 2) }
        + bigEndian(40_000_000, 4)
        + bigEndian(50, 4)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a PNG's mDCv chunk before the image data gives the peak, and a PNG without one none")
    func readsPNGChunk() {
        // Given
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let header = chunk("IHDR", [UInt8](repeating: 0, count: 13))
        let end = chunk("IDAT", []) + chunk("IEND", [])

        // When
        let mastered = MasteringDisplayReader(data: Data(signature + header + chunk("mDCv", Self.volume) + end)).peak()
        let plain = MasteringDisplayReader(data: Data(signature + header + end)).peak()

        // Then
        #expect(mastered == 4000)
        #expect(plain == nil)
    }

    @Test("a HEIF file's mdcv item property in meta, iprp, ipco gives the peak, and one outside it none")
    func readsItemProperty() {
        // Given
        let fileType = box("ftyp", Array("heic".utf8) + [0, 0, 0, 0] + Array("mif1heic".utf8))
        let handler = box("hdlr", [0, 0, 0, 0, 0, 0, 0, 0] + Array("pict".utf8) + [UInt8](repeating: 0, count: 13))
        let colour = box("colr", Array("nclx".utf8) + [0, 9, 0, 16, 0, 9, 0x80])
        let properties = box("iprp", box("ipco", colour + box("mdcv", Self.volume)))
        let meta = box("meta", [0, 0, 0, 0] + handler + properties)
        let loose = box("mdcv", Self.volume)

        // When
        let mastered = MasteringDisplayReader(data: Data(fileType + meta + box("mdat", [1, 2, 3]))).peak()
        let outside = MasteringDisplayReader(data: Data(fileType + loose + box("meta", [0, 0, 0, 0] + handler))).peak()

        // Then
        #expect(mastered == 4000)
        #expect(outside == nil)
    }

    // MARK: - Private
    private static func bigEndian(
        _ value: Int,
        _ count: Int
    ) -> [UInt8] {
        (0..<count).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    }

    // A PNG chunk; the reader does not check its CRC, written as 0.
    private func chunk(
        _ type: String,
        _ data: [UInt8]
    ) -> [UInt8] {
        Self.bigEndian(data.count, 4) + Array(type.utf8) + data + [0, 0, 0, 0]
    }

    private func box(
        _ type: String,
        _ data: [UInt8]
    ) -> [UInt8] {
        Self.bigEndian(data.count + 8, 4) + Array(type.utf8) + data
    }
}
