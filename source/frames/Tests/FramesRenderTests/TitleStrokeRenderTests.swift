//
//  TitleStrokeRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import Testing

@testable import Frames

// A run's stroke width is in output pixels: an "I", white with a red stroke 10 wide on black, shows 5 of red on each
// side of its stem across and on each end of it down, whatever the title's scale or its unit's. Serialized, since
// AVAssetReader needs a free thread of the shared pool.
@Suite("Title Stroke Render Tests", .serialized)
struct TitleStrokeRenderTests {
    // MARK: - Property
    private let presets = [
        "animation/grow": #"""
            { "description": "grows in", "entrance": { "seconds": 1, "keys": [ { "t": 0, "scale": 2 }, { "t": 1, "scale": 2 } ] } }
            """#
    ]

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    // MARK: - Initializer
    // MARK: - Test
    @Test("a title at scale [2, 1] strokes its run at its written width across and down")
    func keepsStrokeWidthUnderScale() throws {
        // Given
        let sequence = try DocumentResolver().resolve(document(title: #""scale": [2, 1]"#))

        // When
        let bitmap = try sut.frame(of: Evaluator().displayList(of: sequence, at: 1))

        // Then
        let (across, down) = redWidths(in: bitmap)
        #expect(abs(across - 10) < 1, "\(across) of red across")
        #expect(abs(down - 10) < 1, "\(down) of red down")
    }

    @Test("a unit at scale 2 in its entrance strokes its run at its written width across and down")
    func keepsStrokeWidthInUnitEntrance() throws {
        // Given
        let resolver = try DocumentResolver(presets: presets)
        let sequence = try resolver.resolve(document(title: #""animation": { "preset": "mine/grow", "by": "word" }"#))

        // When
        let bitmap = try sut.frame(of: Evaluator().displayList(of: sequence, at: 0.5))

        // Then
        let (across, down) = redWidths(in: bitmap)
        #expect(abs(across - 10) < 1, "\(across) of red across")
        #expect(abs(down - 10) < 1, "\(down) of red down")
    }

    // MARK: - Private
    private func document(title keys: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [320, 240], "fps": 10 },
              "theme": { "baseWidth": 320,
                         "styles": { "headline": { "size": 100, "color": "#FFFFFF",
                                                   "stroke": { "width": 10, "color": "#FF0000" },
                                                   "placement": "center", "offset": 0 } } },
              "storyline": [ { "solid": "#000000", "duration": 2 } ],
              "clips": [ { "title": "I", "style": "headline", "at": [0, 2], \#(keys) } ] }
            """#
    }

    // The red shown across the row through the middle of what is drawn and down the column through it: red less
    // green, which is 1 on the stroke, 0 on the white fill and the black, and its coverage on an edge.
    private func redWidths(in bitmap: Bitmap) -> (across: Double, down: Double) {
        let red = { (x: Int, y: Int) in
            let pixel = bitmap.pixel(x: x, y: y)
            return pixel[0] - pixel[1]
        }
        let drawn = (0..<bitmap.height).flatMap { y in (0..<bitmap.width).map { x in (x, y) } }
            .filter { x, y in bitmap.pixel(x: x, y: y)[0] > 0.5 }
        let columns = drawn.map { $0.0 }
        let rows = drawn.map { $0.1 }
        let middle = ((columns.min() ?? 0) + (columns.max() ?? 0)) / 2
        let row = ((rows.min() ?? 0) + (rows.max() ?? 0)) / 2

        let across = (0..<bitmap.width).map { red($0, row) }.reduce(0, +)
        let down = (0..<bitmap.height).map { red(middle, $0) }.reduce(0, +)
        return (across, down)
    }
}
