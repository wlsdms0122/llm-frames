//
//  CurvedPathRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/23/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import Testing

@testable import Frames

// Path shapes and path masks with tangents, resolved, evaluated and drawn: white on a black 320 x 240 frame whose
// theme lengths are output pixels. A pixel is white when its red is above 0.99 and black when below 0.01, each probe
// wholly inside or outside what it tests. Serialized, since AVAssetReader needs a free thread of the shared pool.
@Suite("Curved Path Render Tests", .serialized, .blockingLimit)
struct CurvedPathRenderTests {
    // MARK: - Property
    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    // MARK: - Initializer
    // MARK: - Test
    // The curve from (100, 120) to (220, 120), both tangents (0, 80), bulges to y = 180 at its middle in its parent's
    // space. Its middle and its chord's, carried by the item's transform, lie at least 48 apart under the scale.
    @Test("a curved path under a parent scaled along each axis apart and turned is drawn along its carried curve")
    func drawsCurveUnderParent() throws {
        // Given
        let parent = ##"""
            { "id": "frame", "kind": "rect", "area": [40, 40, 240, 160], "fill": "#000000",
              "scale": [1.3, 0.7], "rotation": 30, "at": [0, 2], "animation": "none" }
            """##
        let curve = ##"""
            { "id": "curve", "parent": "frame", "kind": "path",
              "points": [ { "vertex": [100, 120], "outTangent": [0, 80] },
                          { "vertex": [220, 120], "inTangent": [0, 80] } ],
              "stroke": { "paint": "#FFFFFF", "width": 6 }, "fill": false, "at": [0, 2], "animation": "none" }
            """##
        let sequence = try DocumentResolver().resolve(document(clips: [parent, curve]))
        let list = Evaluator().displayList(of: sequence, at: 1)

        // When
        let bitmap = try sut.bitmap(of: list)

        // Then
        let (middle, chord) = try middles(of: "curve", in: list)
        expect(bitmap, at: [middle, chord], white: [true, false])
    }

    // The tangents ease from 0 to (0, 120) over a second, so the segment from (60, 120) to (260, 120) is straight at
    // 0, bulges to y = 165 at its middle at 0.5 and to y = 210 at 1.
    @Test(
        "a path whose tangents alone are keyframed eases from straight into a curve",
        arguments: [(0.0, [true, false, false]), (0.5, [false, true, false]), (1.0, [false, false, true])]
    )
    func easesTangents(
        time: Double,
        white: [Bool]
    ) throws {
        // Given
        let curve = ##"""
            { "id": "curve", "kind": "path", "points": [[60, 120], [260, 120]],
              "stroke": { "paint": "#FFFFFF", "width": 6 }, "fill": false, "at": [0, 2], "animation": "none",
              "keyframes": [
                { "at": 0, "ease": "linear", "points": [ { "outTangent": [0, 0] }, { "inTangent": [0, 0] } ] },
                { "at": 1, "points": [ { "outTangent": [0, 120] }, { "inTangent": [0, 120] } ] } ] }
            """##
        let sequence = try DocumentResolver().resolve(document(clips: [curve]))

        // When
        let bitmap = try sut.bitmap(of: Evaluator().displayList(of: sequence, at: time))

        // Then
        expect(bitmap, at: [(160, 120), (160, 165), (160, 210)], white: white)
    }

    // Two vertices at (40, 120) and (280, 120) whose tangents bend the segment between them up to y = 45 and the
    // closing one down to y = 195, a lens over a white rect. A feather of 2 leaves the lens's middle and the frame's
    // corners as they are and blurs the edge, half on it.
    @Test("a white rect under a feathered lens path mask shows inside the lens and not outside it")
    func cutsToFeatheredLens() throws {
        // Given
        let rect = ##"""
            { "kind": "rect", "area": [0, 0, 320, 240], "fill": "#FFFFFF", "at": [0, 2], "animation": "none",
              "mask": { "kind": "path", "feather": 2, "points": [
                { "vertex": [40, 120], "inTangent": [60, 100], "outTangent": [60, -100] },
                { "vertex": [280, 120], "inTangent": [-60, -100], "outTangent": [-60, 100] } ] } }
            """##
        let sequence = try DocumentResolver().resolve(document(clips: [rect]))

        // When
        let bitmap = try sut.bitmap(of: Evaluator().displayList(of: sequence, at: 1))

        // Then
        expect(bitmap, at: [(160, 120), (160, 60), (60, 120)], white: [true, true, true])
        expect(bitmap, at: [(160, 20), (160, 220), (20, 120), (40, 60)], white: [false, false, false, false])
        let edge = bitmap.pixel(x: 160, y: 44)[0]
        #expect(edge > 0.2 && edge < 0.8, "\(edge) on the edge")
    }

    // MARK: - Private
    private func document(clips: [String]) -> String {
        #"""
            { "kind": "sequence", "format": { "size": [320, 240], "fps": 10 }, "theme": { "baseWidth": 320 },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
              "clips": [ \#(clips.joined(separator: ", ")) ] }
            """#
    }

    // The pixels holding the middle of a one-segment path's curve and the middle of its chord, carried by its item's
    // transform: a cubic's middle is (P0 + 3 P1 + 3 P2 + P3) / 8.
    private func middles(
        of id: String,
        in list: DisplayList
    ) throws -> (curve: (Int, Int), chord: (Int, Int)) {
        guard case let .items(items) = list.content else {
            Issue.record("the list holds samples")
            return ((0, 0), (0, 0))
        }
        let item = try #require(items.first { $0.origin?.id == id })
        guard
            case let .path(path) = item.content,
            case let .path(vertices, _) = path.geometry,
            vertices.count == 2
        else {
            Issue.record("\(id) is not a path of two vertices")
            return ((0, 0), (0, 0))
        }
        let (start, end) = (vertices[0], vertices[1])
        let first = Point(x: start.vertex.x + start.outTangent.x, y: start.vertex.y + start.outTangent.y)
        let second = Point(x: end.vertex.x + end.inTangent.x, y: end.vertex.y + end.inTangent.y)
        let weighted = { (from: Double, first: Double, second: Double, to: Double) -> Double in
            (from + 3 * first + 3 * second + to) / 8
        }
        let curve = Point(
            x: weighted(start.vertex.x, first.x, second.x, end.vertex.x),
            y: weighted(start.vertex.y, first.y, second.y, end.vertex.y)
        )
        let chord = Point(x: (start.vertex.x + end.vertex.x) / 2, y: (start.vertex.y + end.vertex.y) / 2)
        let pixel = { (point: Point) in
            let carried = item.transform.apply(to: point)
            return (Int(carried.x), Int(carried.y))
        }

        return (pixel(curve), pixel(chord))
    }

    private func expect(
        _ bitmap: Bitmap,
        at pixels: [(Int, Int)],
        white: [Bool],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for ((x, y), isWhite) in zip(pixels, white) {
            let red = bitmap.pixel(x: x, y: y)[0]
            #expect(
                isWhite ? red > 0.99 : red < 0.01,
                "pixel (\(x), \(y)) has red \(red), expected \(isWhite ? "white" : "black")",
                sourceLocation: sourceLocation
            )
        }
    }
}
