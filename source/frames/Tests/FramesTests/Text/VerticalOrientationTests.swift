//
//  VerticalOrientationTests.swift
//  FramesTests
//
//  Created by JSilver on 11/23/26.
//

import Testing

@testable import Frames

@Suite("Vertical Orientation Tests")
struct VerticalOrientationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a scalar takes the Vertical_Orientation of UAX #50, and an unassigned one the default of its block",
        arguments: [
            ("\u{6F22}", VerticalOrientation.upright),
            ("\u{AC00}", .upright),
            ("\u{FF21}", .upright),
            ("\u{00A7}", .upright),
            ("\u{3001}", .transformedUpright),
            ("\u{3002}", .transformedUpright),
            ("\u{300C}", .transformedRotated),
            ("\u{30FC}", .transformedRotated),
            ("A", .rotated),
            ("1", .rotated),
            ("\u{05D0}", .rotated),
            ("\u{FF71}", .rotated),
            ("\u{2FFFD}", .upright),
            ("\u{E0080}", .rotated)
        ] as [(Unicode.Scalar, VerticalOrientation)]
    )
    func readsOrientation(
        scalar: Unicode.Scalar,
        orientation: VerticalOrientation
    ) {
        // When
        let sut = VerticalOrientation(scalar)

        // Then
        #expect(sut == orientation)
    }

    @Test("every orientation stands upright in a vertical line but `rotated`, which is set sideways")
    func standsUpright() {
        // Given
        let orientations: [VerticalOrientation] = [.upright, .transformedUpright, .transformedRotated, .rotated]

        // When
        let upright = orientations.map { sut in sut.isUpright }

        // Then
        #expect(upright == [true, true, true, false])
    }
}
