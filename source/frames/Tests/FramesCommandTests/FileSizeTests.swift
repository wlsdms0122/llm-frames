//
//  FileSizeTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import FramesCommand

@Suite("FileSize Tests")
struct FileSizeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a size is bytes below a kilobyte and SI units with one decimal above, carried to the next unit when it rounds up",
        arguments: [
            (Int64(0), "0 B"),
            (840, "840 B"),
            (999, "999 B"),
            (1000, "1.0 kB"),
            (3449, "3.4 kB"),
            (999_949, "999.9 kB"),
            (999_950, "1.0 MB"),
            (12_345_678, "12.3 MB"),
            (2_500_000_000, "2.5 GB")
        ]
    )
    func describesSize(
        bytes: Int64,
        text: String
    ) {
        // Given
        let sut = FileSize(bytes: bytes)

        // When
        let description = sut.description

        // Then
        #expect(description == text)
    }

    // MARK: - Private
}
