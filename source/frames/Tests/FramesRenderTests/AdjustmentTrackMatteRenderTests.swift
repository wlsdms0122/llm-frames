//
//  AdjustmentTrackMatteRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Adjustment clips cut by a track matte (FRAMES-11 Adjustment clips), resolved on the real providers and drawn by the
// real decoder and renderer.
@Suite("Adjustment Track Matte Render Tests", .serialized)
struct AdjustmentTrackMatteRenderTests {
    // MARK: - Property
    private static let grey = #"{ "description": "every colour turned to its grey", "ops": [ { "op": "saturation", "amount": 0 } ] }"#

    // MARK: - Initializer
    // MARK: - Test
    @Test("an adjustment's filtered backdrop is cut by its track matte, and the backdrop outside the matte is left as it is")
    func cutsAdjustmentByTrackMatte() throws {
        // Given
        let bitmap = try frame(matte: ##"{ "id": "m", "shape": "rect", "area": [0, 0, 80, 90], "fill": "#FFFFFF", "at": [0, 1] }"##)

        // When
        let inside = bitmap.pixel(x: 40, y: 45)
        let outside = bitmap.pixel(x: 120, y: 45)

        // Then
        expectGrey(inside)
        expectRed(outside)
    }

    @Test("an adjustment whose track matte is a shape with a corner pin filters the backdrop inside the corner pin only")
    func cutsAdjustmentByCornerPinnedMatte() throws {
        // Given
        let bitmap = try frame(matte: ##"""
            { "id": "m", "shape": "rect", "width": 100, "height": 50, "fill": "#FFFFFF", "at": [0, 1],
              "cornerPin": [[20, 10], [140, 20], [130, 80], [30, 70]] }
            """##)

        // When
        let inside = bitmap.pixel(x: 80, y: 45)
        let outsideTop = bitmap.pixel(x: 20, y: 30)
        let outsideCorner = bitmap.pixel(x: 150, y: 85)

        // Then
        expectGrey(inside)
        expectRed(outsideTop)
        expectRed(outsideCorner)
    }

    // MARK: - Private
    // A red still under an adjustment that turns colours grey, cut by the alpha of `matte`, at 0.5.
    private func frame(matte: String) throws -> Bitmap {
        let directory = try TemporaryDirectory()
        let red = directory.file("red.png")
        try ColorImageWriter(size: Size(width: 160, height: 90), colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            .write(to: red, codeValues: [255, 0, 0])
        let document = try DocumentResolver(presets: ["filter/grey": Self.grey]).resolve(#"""
            { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
              "storyline": [ { "media": "\#(red)", "duration": 1 } ],
              "clips": [ \#(matte),
                         { "adjust": "mine/grey", "at": [0, 1], "trackMatte": { "clip": "m", "mode": "alpha" } } ] }
            """#)

        return try QuartzRenderer(decoder: AVFoundationDecoder()).frame(of: Evaluator().displayList(of: document, at: 0.5))
    }

    private func expectGrey(
        _ pixel: [Double],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            abs(pixel[0] - pixel[1]) < 0.01 && abs(pixel[1] - pixel[2]) < 0.01 && pixel[0] > 0.1 && pixel[0] < 0.9,
            "\(pixel) is not grey",
            sourceLocation: sourceLocation
        )
    }

    private func expectRed(
        _ pixel: [Double],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            abs(pixel[0] - 1) < 0.01 && pixel[1] < 0.01 && pixel[2] < 0.01,
            "\(pixel) is not red",
            sourceLocation: sourceLocation
        )
    }
}
