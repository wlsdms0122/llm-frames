//
//  ProcessMemoryMeterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/26/26.
//

import IOSurface
import Testing

@testable import Frames

// The process's meter reads its footprint as the system counts it, the IOSurfaces the process makes among it
// (FRAMES-30 What it measures).
@Suite("ProcessMemoryMeter Tests")
struct ProcessMemoryMeterTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("the footprint holds the IOSurfaces the process has made and written, and the peak is at least the footprint")
    func readsSurfaces() throws {
        // Given
        let sut = ProcessMemoryMeter()
        let surfaces = try (0..<4).map { _ in
            try #require(IOSurface(properties: [
                .width: 1024,
                .height: 1024,
                .bytesPerElement: 8,
                .pixelFormat: 0x5247_6841
            ]))
        }
        for surface in surfaces {
            surface.lock(options: [], seed: nil)
            surface.baseAddress.initializeMemory(as: UInt8.self, repeating: 1, count: surface.allocationSize)
            surface.unlock(options: [], seed: nil)
        }

        // When
        let reading = sut.read()

        // Then
        #expect(reading.footprint >= surfaces.reduce(0) { $0 + $1.allocationSize })
        #expect(reading.peak >= reading.footprint)
        withExtendedLifetime(surfaces) {}
    }
}
