//
//  TitleUnitRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import Testing

@testable import Frames

// Titles animated by word drawn by the real renderer from documents resolved on the real shaper, against the same
// titles not animated by unit. Serialized, since AVAssetReader needs a free thread of the shared pool.
@Suite("Title Unit Render Tests", .serialized)
struct TitleUnitRenderTests {
    // MARK: - Property
    private let presets = [
        "animation/rise": #"""
            { "description": "rises in", "entrance": { "seconds": 0.3, "keys": [ { "t": 0, "y": 0.5, "opacity": 0 }, { "t": 1, "y": 0 } ] } }
            """#,
        "animation/fade": #"""
            { "description": "fades in", "entrance": { "seconds": 1, "ease": "linear", "keys": [ { "t": 0, "opacity": 0 }, { "t": 1, "opacity": 1 } ] } }
            """#
    ]

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    // MARK: - Initializer
    // MARK: - Test
    @Test("at rest a title by word draws as it does without `by`, at opacity 0.5 with `multiply`, a feathered mask and a luma matte")
    func matchesTitleAtRest() throws {
        // Given
        let resolver = try DocumentResolver(presets: presets)
        let byWord = try resolver.resolve(document(title: #""animation": { "preset": "mine/rise", "by": "word" }"#))
        let whole = try resolver.resolve(document(title: #""animation": "mine/rise""#))

        // When
        let drawn = try sut.frame(of: Evaluator().displayList(of: byWord, at: 1))
        let expected = try sut.frame(of: Evaluator().displayList(of: whole, at: 1))

        // Then
        // The group's list is drawn into a bitmap of its own before it is composited, so its colours round once more.
        let largest = largestDifference(drawn, expected)
        #expect(largest <= 3.0 / 255, "the largest difference is \(largest * 255) of 255")
    }

    @Test("at rest a title by word with a stroke and a padded highlight draws its edges as it does without `by`")
    func matchesEdgesAtRest() throws {
        // Given
        let resolver = try DocumentResolver(presets: presets)
        let byWord = try resolver.resolve(edged(animation: #"{ "preset": "mine/rise", "by": "word" }"#))
        let whole = try resolver.resolve(edged(animation: #""mine/rise""#))

        // When
        let drawn = try sut.frame(of: Evaluator().displayList(of: byWord, at: 1))
        let expected = try sut.frame(of: Evaluator().displayList(of: whole, at: 1))

        // Then
        let largest = largestDifference(drawn, expected)
        #expect(largest <= 3.0 / 255, "the largest difference is \(largest * 255) of 255")
    }

    @Test("a unit entering at opacity 0.5 shows its stroke through its own fill, where the whole title at 0.5 does not")
    func showsStrokeThroughFill() throws {
        // Given
        let resolver = try DocumentResolver(presets: presets)
        let byWord = try resolver.resolve(outlined(animation: #"{ "preset": "mine/fade", "by": "word" }"#))
        let whole = try resolver.resolve(outlined(animation: #""mine/fade""#))

        // When
        let unit = try sut.frame(of: Evaluator().displayList(of: byWord, at: 0.5))
        let title = try sut.frame(of: Evaluator().displayList(of: whole, at: 0.5))

        // Then
        // On black, white over red at 0.5 each is (0.75, 0.5, 0.5) where the fill covers the stroke's inner half, and
        // the whole title at 0.5 draws its fill there, (0.5, 0.5, 0.5).
        let unitCount = strokeUnderFill(in: unit)
        let titleCount = strokeUnderFill(in: title)
        #expect(unitCount > 200)
        #expect(titleCount * 10 < unitCount, "\(titleCount) pixels of the whole title, \(unitCount) of the unit")
    }

    // MARK: - Private
    private func document(title animation: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [320, 180], "fps": 10 },
              "theme": { "baseWidth": 320,
                         "styles": { "headline": { "size": 60, "color": "#FFFFFF", "stroke": { "width": 6, "color": "#CC2200" },
                                                   "highlight": { "color": "#2255FF", "padding": [4, 6], "radius": 6 },
                                                   "underline": { "width": 4, "offset": 6, "color": "#FFCC00" },
                                                   "placement": "center", "offset": 0 } } },
              "storyline": [ { "kind": "solid", "color": "#88AA66", "duration": 2 } ],
              "clips": [
                { "id": "m", "kind": "rect", "area": [0, 0, 200, 180], "fill": "#B0B0B0", "at": [0, 2] },
                { "kind": "title", "text": "AB CD", "style": "headline", "at": [0, 2], "opacity": 0.5, "blend": "multiply",
                  "mask": { "shape": "ellipse", "area": [0, 0, 160, 70], "feather": 8 },
                  "trackMatte": { "clip": "m", "mode": "luma" }, \#(animation) } ] }
            """#
    }

    // Nothing cuts the title, so every edge of its stroke and its highlight's padding shows.
    private func edged(animation: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [320, 180], "fps": 10 },
              "theme": { "baseWidth": 320,
                         "styles": { "headline": { "size": 60, "color": "#FFFFFF", "stroke": { "width": 10, "color": "#CC2200" },
                                                   "highlight": { "color": "#2255FF", "padding": [12, 16], "radius": 6 },
                                                   "placement": "center", "offset": 0 } } },
              "storyline": [ { "kind": "solid", "color": "#88AA66", "duration": 2 } ],
              "clips": [ { "kind": "title", "text": "AB CD", "style": "headline", "at": [0, 2], "animation": \#(animation) } ] }
            """#
    }

    private func outlined(animation: String) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [320, 180], "fps": 10 },
              "theme": { "baseWidth": 320,
                         "styles": { "headline": { "size": 100, "color": "#FFFFFF", "stroke": { "width": 10, "color": "#FF0000" },
                                                   "placement": "center", "offset": 0 } } },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
              "clips": [ { "kind": "title", "text": "HI", "style": "headline", "at": [0, 2], "animation": \#(animation) } ] }
            """#
    }

    private func largestDifference(
        _ bitmap: Bitmap,
        _ other: Bitmap
    ) -> Double {
        (0..<bitmap.height).flatMap { y in (0..<bitmap.width).map { x in (x, y) } }
            .map { x, y in zip(bitmap.pixel(x: x, y: y), other.pixel(x: x, y: y)).map { abs($0 - $1) }.max() ?? 0 }
            .max() ?? 0
    }

    private func strokeUnderFill(in bitmap: Bitmap) -> Int {
        (0..<bitmap.height).flatMap { y in (0..<bitmap.width).map { x in bitmap.pixel(x: x, y: y) } }
            .filter { pixel in pixel[0] > pixel[1] + 0.15 && pixel[1] > 0.4 }
            .count
    }
}
