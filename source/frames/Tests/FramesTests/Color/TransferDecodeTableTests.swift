//
//  TransferDecodeTableTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

@testable import Frames
import Testing

@Suite("TransferDecodeTable Tests")
struct TransferDecodeTableTests {
    // MARK: - Property
    private static let transfers: [TransferFunction] = [
        .sRGB,
        .bt1886,
        .gamma(2.2),
        .gamma(2.8),
        .smpte240M,
        .linear,
        .logarithmic100,
        .logarithmic316,
        .xvYCC,
        .bt1361,
        .smpte428
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("every half-float value, NaN and infinity among them, decodes to the transfer's own bits", arguments: transfers)
    func decodesHalfFloats(transfer: TransferFunction) {
        // Given
        let sut = TransferDecodeTable(transfer)

        // When
        let mismatches = (0...UInt16.max).filter { bits in
            let encoded = Double(Float16(bitPattern: bits))
            return sut.decode(encoded).bitPattern != transfer.decode(encoded).bitPattern
        }

        // Then
        #expect(mismatches.isEmpty)
    }

    @Test("a value that is not a half float decodes to the transfer's own bits", arguments: transfers)
    func decodesOtherValues(transfer: TransferFunction) {
        // Given
        let sut = TransferDecodeTable(transfer)
        let halves = (0...UInt16.max).map { Float16(bitPattern: $0) }.filter(\.isFinite)
        let between = halves.flatMap { [Double(Float($0).nextUp), Double($0).nextDown, Double($0) / 3] }
        let nonNumbers = ([0x7FF8_0000_0000_0001, 0xFFF8_0000_0000_0000, 0x7FF0_0000_0000_0001] as [UInt64])
            .map(Double.init(bitPattern:))

        // When
        let mismatches = (between + nonNumbers + [0.3, -0.3, 1 / 3]).filter { encoded in
            sut.decode(encoded).bitPattern != transfer.decode(encoded).bitPattern
        }

        // Then
        #expect(mismatches.isEmpty)
    }

    // MARK: - Private
}
