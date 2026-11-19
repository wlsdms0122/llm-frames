//
//  TransferFunctionTests.swift
//  FramesTests
//
//  Created by JSilver on 11/20/26.
//

@testable import Frames
import Testing

@Suite("TransferFunction Tests")
struct TransferFunctionTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "decoding an encoded value gives the linear value back, on all real numbers",
        arguments: [TransferFunction.sRGB, .bt2020, .bt1886],
        [-2.5, -0.5, -0.001, 0, 0.002, 0.01, 0.18, 0.5, 1, 4]
    )
    func roundTrips(
        transfer: TransferFunction,
        linear: Double
    ) {
        // Given
        let sut = transfer

        // When
        let decoded = sut.decode(sut.encode(linear))

        // Then
        #expect(abs(decoded - linear) < 1e-12)
    }

    @Test(
        "the extended sRGB transfer keeps the sign and the same curve above 1",
        arguments: [
            (0.5, 0.7353569830524495),
            (1.0, 1.0),
            (-0.5, -0.7353569830524495),
            (2.0, 1.3532560461493863),
            (0.001, 0.01292)
        ]
    )
    func encodesExtendedSRGB(
        linear: Double,
        expected: Double
    ) {
        // Given
        let sut = TransferFunction.sRGB

        // When
        let encoded = sut.encode(linear)

        // Then
        #expect(abs(encoded - expected) < 1e-12)
    }

    @Test("BT.1886 at a white of 1 and a black of 0 is a power of 2.4")
    func decodesBT1886() {
        // Given
        let sut = TransferFunction.bt1886

        // When
        let decoded = sut.decode(0.5)

        // Then
        #expect(abs(decoded - 0.18946457081379978) < 1e-12)
    }
}
