//
//  CubeReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
@testable import Frames
import FramesTestMedia
import Testing

@Suite("CubeReader Tests")
struct CubeReaderTests {
    // MARK: - Property
    private let identity = """
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1
        """

    // MARK: - Initializer
    // MARK: - Test
    @Test("a cube file gives its title, size, domain and entries, red varying fastest, past comments and blank lines")
    func readsCube() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("warm.cube")
        let text = """
            # A warm look
            TITLE "Warm look"

            LUT_3D_SIZE 2
            DOMAIN_MIN 0 0 0.1
            DOMAIN_MAX 1 1 0.9\r
            0.1 0.2 0.3
            0.9 0.2 0.3
            # between entries
            0.1 0.8 0.3
            0.9 0.8 0.3
            0.1 0.2 0.7
            0.9 0.2 0.7
            0.1 0.8 0.7
            0.9 0.8 0.7

            """
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        let sut = CubeReader()

        // When
        let cube = try sut.read(contentsOf: path)

        // Then
        #expect(cube.title == "Warm look")
        #expect(cube.size == 2)
        #expect(cube.domainMin == [0, 0, 0.1])
        #expect(cube.domainMax == [1, 1, 0.9])
        #expect(cube.values.count == 24)
        #expect(Array(cube.values[0..<6]) == [0.1, 0.2, 0.3, 0.9, 0.2, 0.3])
        #expect(Array(cube.values[18..<24]) == [0.1, 0.8, 0.7, 0.9, 0.8, 0.7])
    }

    @Test("Resolve's LUT_3D_INPUT_RANGE sets the domain of every channel")
    func readsInputRange() throws {
        // Given
        let text = "LUT_3D_INPUT_RANGE -0.5 1.5\nLUT_3D_SIZE 2\n" + identity
        let sut = CubeReader()

        // When
        let cube = try sut.read(text, file: "range.cube")

        // Then
        #expect(cube.domainMin == [-0.5, -0.5, -0.5])
        #expect(cube.domainMax == [1.5, 1.5, 1.5])
    }

    @Test(
        "a 1D LUT and a malformed file stop with the file and line",
        arguments: [
            ("LUT_1D_SIZE 2\n0 0 0\n1 1 1", 1),
            ("0 0 0\nLUT_3D_SIZE 2", 1),
            ("LUT_3D_SIZE 1\n0 0 0", 1),
            ("LUT_3D_SIZE 2.5", 1),
            ("LUT_3D_SIZE 2\nSHAPER 1", 2),
            ("LUT_3D_SIZE 2\n0 0\n", 2),
            ("LUT_3D_SIZE 2\n0 0 x\n", 2),
            ("LUT_3D_SIZE 2\n0 0 0\n1 0 0\n", 4),
            ("LUT_3D_SIZE 2\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1\n1 1 1", 10),
            ("LUT_3D_SIZE 2\n0 0 0\nDOMAIN_MIN 0 0 0", 3),
            ("DOMAIN_MIN 0 0 1\nLUT_3D_SIZE 2\n0 0 0\n1 0 0\n0 1 0\n1 1 0\n0 0 1\n1 0 1\n0 1 1\n1 1 1", 1),
            ("TITLE \"empty\"", 1)
        ]
    )
    func stopsOnMalformedFile(
        text: String,
        line: Int
    ) {
        // Given
        let sut = CubeReader()

        // When
        let error = #expect(throws: FilterError.self) {
            try sut.read(text, file: "/looks/bad.cube")
        }

        // Then
        guard case let .malformedCube(file, errorLine, _) = error else {
            Issue.record("expected a malformed cube, got \(String(describing: error))")
            return
        }
        #expect(file == "/looks/bad.cube")
        #expect(errorLine == line)
        #expect(error?.description.hasPrefix("/looks/bad.cube: line \(line): ") == true)
    }

    @Test("a file that is not there stops naming it")
    func stopsOnMissingFile() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("missing.cube")
        let sut = CubeReader()

        // When
        let error = #expect(throws: FilterError.self) {
            try sut.read(contentsOf: path)
        }

        // Then
        #expect(error == .unreadableCube(file: path))
    }
}
