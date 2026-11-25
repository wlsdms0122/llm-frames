//
//  MotionBlurRenderTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Frames with motion blur evaluated from resolved documents and drawn by the real renderer (FRAMES-24, FRAMES-29).
@Suite("Motion Blur Render Tests", .serialized, .blockingLimit)
struct MotionBlurRenderTests {
    // MARK: - Property
    private let presets = [
        "transition/push": #"""
            { "description": "the incoming clip pushes the outgoing one out to the left", "seconds": 1, "ease": "linear",
              "incoming": { "keys": [ { "t": 0, "x": 1 }, { "t": 1, "x": 0 } ] },
              "outgoing": { "keys": [ { "t": 0, "x": 0 }, { "t": 1, "x": -1 } ] } }
            """#,
        "animation/wipe": #"""
            { "description": "wipes in from the left", "entrance": { "seconds": 0.2, "ease": "linear", "revealFrom": "left",
              "keys": [ { "t": 0, "reveal": 0 }, { "t": 1, "reveal": 1 } ] } }
            """#
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sliding clip is smeared over the distance it moves while the shutter is open, in samplesPerFrame steps")
    func smearsAlongMotion() throws {
        // Given
        // 1600 pixels a second at 25 fps under the default shutter is 32 pixels of exposure in 16 steps of 2.
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [400, 20], "fps": 25 },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
              "clips": [ { "kind": "rect", "fill": "#FFFFFF", "at": [0, 2], "width": 40, "height": 20, "motionBlur": true,
                           "keyframes": [ { "at": 0, "position": [60, 10], "ease": "linear" }, { "at": 0.2, "position": [380, 10] } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frame = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.08))

        // Then
        let reds = (0..<frame.width).map { frame.pixel(x: $0, y: 10)[0] }
        let partial = reds.filter { $0 > 0.001 && $0 < 0.999 }
        #expect(partial.count == 2 * 30)
        #expect(reds.filter { $0 >= 0.999 }.count == 10)
        #expect(Set(partial.map { ($0 * 16).rounded() }) == Set((1...15).map { Double($0) }))
        #expect(partial.allSatisfy { abs($0 * 16 - ($0 * 16).rounded()) < 0.01 })
    }

    @Test("a page growing while the shutter is open is drawn from its samples, its edges smeared over the distance they move")
    func smearsGrowingPage() throws {
        // Given
        // The white 100 point page fills the 200 pixel frame at scale 1 and grows from scale 0.5 at 0 to 1 at 0.2, so
        // over the 0.02 seconds of the exposure of the frame at 0.08 each of its edges moves 5 pixels outward.
        let directory = try TemporaryDirectory()
        let path = directory.file("white.pdf")
        try PageWriter().write(width: 100, height: 100, content: "1 g 0 0 100 100 re f", to: path)
        let document = { (isMotionBlurred: Bool) in
            try DocumentResolver().resolve(#"""
                { "kind": "sequence", "format": { "size": [200, 200], "fps": 25 },
                  "storyline": [ { "kind": "media", "media": "\#(path)", "duration": 2, "motionBlur": \#(isMotionBlurred),
                                   "keyframes": [ { "at": 0, "scale": 0.5, "ease": "linear" }, { "at": 0.2, "scale": 1 } ] } ] }
                """#)
        }
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let blurred = try sut.bitmap(of: Evaluator().displayList(of: document(true), at: 0.08))
        let sharp = try sut.bitmap(of: Evaluator().displayList(of: document(false), at: 0.08))

        // Then
        let partial = { (frame: Bitmap) in
            (0..<frame.width).map { frame.pixel(x: $0, y: 100)[0] }.filter { $0 > 0.001 && $0 < 0.999 }.count
        }
        #expect(blurred.pixel(x: 100, y: 100)[0] > 0.999)
        #expect(partial(blurred) >= partial(sharp) + 6)
    }

    @Test("a frame where nothing with motion blur moves is the same picture, value for value, as the frame without it")
    func keepsStillFrameExact() throws {
        // Given
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [64, 36], "fps": 25 },
              "storyline": [ { "kind": "solid", "color": "#203040", "duration": 1 } ],
              "clips": [ { "kind": "ellipse", "fill": "#FF8000", "at": [0, 1], "width": 23, "height": 17, "position": [30.3, 17.6],
                           "opacity": 0.7, "motionBlur": true } ] }
            """#)
        let evaluator = Evaluator()
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let list = evaluator.displayList(of: document, at: 0.4)
        let frame = try sut.bitmap(of: list)
        let sharp = try sut.bitmap(of: evaluator.displayListWithoutMotionBlur(of: document, at: 0.4))

        // Then
        guard case let .samples(samples) = list.content else { Issue.record("the list holds items"); return }

        #expect(samples.count == 16)
        #expect(frame.pixels == sharp.pixels)
    }

    @Test(
        "an adjustment whose wipe is complete is the same picture, value for value, as the frame without motion blur when nothing moves",
        arguments: [
            #"{ "kind": "rect", "area": [12.3, 8.6, 30.2, 17.1], "feather": 3 }"#,
            #"{ "kind": "ellipse", "area": [12.3, 8.6, 30.2, 17.1], "feather": 2, "invert": true }"#
        ]
    )
    func keepsCompleteAdjustmentWipeExact(mask: String) throws {
        // Given
        let document = try DocumentResolver(presets: presets).resolve(#"""
            { "kind": "sequence", "format": { "size": [64, 36], "fps": 25 },
              "storyline": [ { "kind": "solid", "color": "#203040", "duration": 1 } ],
              "clips": [ { "kind": "ellipse", "fill": "#FF8000", "at": [0, 1], "width": 40, "height": 24, "position": [32, 18] },
                         { "kind": "adjustment", "adjust": [ { "kind": "exposure", "ev": 1 } ], "at": [0, 1], "animation": "mine/wipe", "motionBlur": true,
                           "mask": \#(mask) } ] }
            """#)
        let evaluator = Evaluator()
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let list = evaluator.displayList(of: document, at: 0.6)
        let frame = try sut.bitmap(of: list)
        let sharp = try sut.bitmap(of: evaluator.displayListWithoutMotionBlur(of: document, at: 0.6))

        // Then
        guard case let .samples(samples) = list.content else { Issue.record("the list holds items"); return }

        #expect(samples.allSatisfy { $0.last?.reveal != nil })
        #expect(frame.pixels == sharp.pixels)
    }

    @Test("the two pictures of a push brought in by a clip with motion blur meet at the seam on every frame", arguments: [1.52, 2.0, 2.48])
    func closesPushSeam(time: Double) throws {
        // Given
        // The push runs from 1.5 to 2.5 over 1600 pixels, so the seam steps 2 pixels from instant to instant and lies
        // on a pixel edge in every sample.
        let document = try DocumentResolver(presets: presets).resolve(#"""
            { "kind": "sequence", "format": { "size": [1600, 4], "fps": 25, "background": "#00000000" },
              "storyline": [ { "kind": "solid", "color": "#FF0000", "duration": 2 },
                             { "kind": "solid", "color": "#0000FF", "duration": 2, "transition": "mine/push", "motionBlur": true } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let list = Evaluator().displayList(of: document, at: time)
        let frame = try sut.bitmap(of: list)

        // Then
        guard case .samples = list.content else { Issue.record("the list holds items"); return }
        #expect((0..<frame.width).allSatisfy { abs(frame.pixel(x: $0, y: 2)[3] - 1) < 0.001 })
        #expect((0..<frame.width).contains { frame.pixel(x: $0, y: 2)[0] < 0.999 && frame.pixel(x: $0, y: 2)[2] < 0.999 })
    }

    @Test("a position that jumps by step inside the exposure shows no double image, only the side that holds T")
    func showsNoDoubleImageAtStep() throws {
        // Given
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [200, 20], "fps": 25 },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
              "clips": [ { "kind": "rect", "fill": "#FFFFFF", "at": [0, 2], "width": 20, "height": 20, "motionBlur": true,
                           "keyframes": [ { "at": 1, "position": [30, 10], "ease": "step" }, { "at": 1.53, "position": [150, 10] } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let before = try sut.bitmap(of: Evaluator().displayList(of: document, at: 1.52))
        let after = try sut.bitmap(of: Evaluator().displayList(of: document, at: 1.56))

        // Then
        let lit = { (frame: Bitmap) in (0..<frame.width).filter { frame.pixel(x: $0, y: 10)[0] > 0.001 } }
        #expect(lit(before) == Array(20..<40))
        #expect(lit(after) == Array(140..<160))
        #expect(lit(before).allSatisfy { before.pixel(x: $0, y: 10)[0] >= 0.999 })
    }

    @Test("under the default shutter a clip that starts on a frame boundary moves over the whole exposure of its first frame")
    func movesOverFirstFrame() throws {
        // Given
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [400, 20], "fps": 25 },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
              "clips": [ { "kind": "rect", "fill": "#FFFFFF", "at": [0.4, 2], "width": 40, "height": 20, "motionBlur": true,
                           "keyframes": [ { "at": 0.4, "position": [60, 10], "ease": "linear" }, { "at": 0.6, "position": [380, 10] } ] } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let frame = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.4))

        // Then
        let reds = (0..<frame.width).map { frame.pixel(x: $0, y: 10)[0] }
        #expect(reds.filter { $0 > 0.001 && $0 < 0.999 }.count == 2 * 30)
    }

    @Test("a looped spin that meets itself blurs through its seam as through any other part of its period")
    func blursThroughLoopSeam() throws {
        // Given
        // A bar spins a whole turn a second about the frame's centre, so the frame at 0.99, whose exposure holds the
        // seam at 1, sweeps from -3.6 to 3.6 degrees, and the frame at 0.49 from 176.4 to 183.6: the same picture turned
        // half a turn, which leaves the bar as it is.
        let spin = #"""
            { "description": "spins", "loop": { "period": 1, "ease": "linear", "keys": [ { "t": 0, "rotation": 0 }, { "t": 1, "rotation": 360 } ] } }
            """#
        let document = try DocumentResolver(presets: ["animation/spin": spin]).resolve(#"""
            { "kind": "sequence", "format": { "size": [200, 200], "fps": 25 },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
              "clips": [ { "kind": "rect", "fill": "#FFFFFF", "at": [0, 2], "width": 160, "height": 20, "position": [100, 100],
                           "animation": "mine/spin", "motionBlur": true } ] }
            """#)
        let sut = QuartzRenderer(decoder: AVFoundationDecoder())

        // When
        let seam = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.99))
        let middle = try sut.bitmap(of: Evaluator().displayList(of: document, at: 0.49))

        // Then
        let points = (0..<200).flatMap { y in (0..<200).map { x in (x: x, y: y) } }
        let difference = points.map { abs(seam.pixel(x: $0.x, y: $0.y)[0] - middle.pixel(x: 199 - $0.x, y: 199 - $0.y)[0]) }
        #expect((difference.max() ?? 1) < 0.01)
        #expect(points.contains { (0.01...0.99).contains(seam.pixel(x: $0.x, y: $0.y)[0]) && abs($0.x - 100) > 70 })
    }

    // MARK: - Private
}
