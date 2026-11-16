//
//  BlackbodyTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames
import Testing

@Suite("Blackbody Tests")
struct BlackbodyTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a blackbody's colour lies on the Planckian locus of the CIE 1931 2° observer",
        arguments: [
            (2856.0, 0.4476, 0.4074),
            (6500.0, 0.3135, 0.3236)
        ]
    )
    func liesOnPlanckianLocus(
        temperature: Double,
        x: Double,
        y: Double
    ) {
        // Given
        let sut = Blackbody(temperature: temperature)

        // When
        let xyz = sut.xyz()
        let chromaticity = Chromaticity(xyz: xyz)

        // Then
        #expect(xyz.y == 1)
        #expect(abs(chromaticity.x - x) < 0.002)
        #expect(abs(chromaticity.y - y) < 0.002)
    }
}
