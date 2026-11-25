//
//  TrackMatteRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/23/26.
//

import CoreGraphics
import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Track mattes read from their matte clip as it is drawn (FRAMES-11 Masks and track mattes), resolved on the real
// providers and drawn by the real decoder and renderer.
@Suite("Track Matte Render Tests", .serialized)
struct TrackMatteRenderTests {
    // MARK: - Property
    private static let white = #"{ "description": "mid grey pushed to white", "ops": [ { "kind": "levels", "input": [0, 0.5], "output": [0, 1] } ] }"#

    // MARK: - Initializer
    // MARK: - Test
    @Test("a luma matte from a mid grey clip whose `levels` filter pushes it to white reveals the picture fully")
    func readsLumaMatteThroughFilter() throws {
        // Given
        let filtered = try frame(matteFilter: #", "filter": "mine/white""#)
        let unfiltered = try frame(matteFilter: "")

        // When
        let revealed = filtered.pixel(x: 80, y: 45)
        let blended = unfiltered.pixel(x: 80, y: 45)

        // Then
        #expect(abs(revealed[0]) < 0.01 && abs(revealed[1]) < 0.01 && abs(revealed[2] - 1) < 0.01, "\(revealed)")
        #expect(blended[0] > 0.1 && blended[2] > 0.1, "\(blended)")
    }

    // MARK: - Private
    // A blue still over a red one, cut by the luma of a mid grey still that writes `matteFilter`, at 0.5.
    private func frame(matteFilter: String) throws -> Bitmap {
        let directory = try TemporaryDirectory()
        let size = Size(width: 160, height: 90)
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let red = directory.file("red.png")
        let blue = directory.file("blue.png")
        let grey = directory.file("grey.png")
        try ColorImageWriter(size: size, colorSpace: sRGB).write(to: red, codeValues: [255, 0, 0])
        try ColorImageWriter(size: size, colorSpace: sRGB).write(to: blue, codeValues: [0, 0, 255])
        try ColorImageWriter(size: size, colorSpace: sRGB).write(to: grey, codeValues: [128, 128, 128])
        let document = try DocumentResolver(presets: ["filter/white": Self.white]).resolve(#"""
            { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(red)", "duration": 1 } ],
              "clips": [ { "id": "m", "kind": "media", "media": "\#(grey)", "at": [0, 1]\#(matteFilter) },
                         { "kind": "media", "media": "\#(blue)", "at": [0, 1], "trackMatte": { "clip": "m", "mode": "luma" } } ] }
            """#)

        return try QuartzRenderer(decoder: AVFoundationDecoder()).bitmap(of: Evaluator().displayList(of: document, at: 0.5))
    }
}
