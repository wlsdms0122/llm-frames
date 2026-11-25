//
//  AgreementCase.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/25/26.
//

import CoreGraphics
import Foundation
import FramesTestMedia

@testable import Frames

// A resolved document, the times of the frames two renderers are compared on and the checks it is held to, one for
// each kind of item and operation a renderer draws: a video under a moving title, a scaled still with opacity and a
// blend mode, a detailed still scaled by 0.625 and by 1.375 and one turned, hard edges of a shape and of a picture at
// sub-pixel positions, shapes with strokes, rounded corners, a shadow and a feathered mask, an adjustment cut by a
// track matte, a crossfade between two detailed pictures, a corner pin, motion blur, and a list composited in the
// linear form.
struct AgreementCase {
    // MARK: - Property
    private static let grey = #"{ "description": "every colour turned to its grey", "ops": [ { "kind": "saturation", "amount": 0 } ] }"#
    private static let fade = #"""
        { "description": "the incoming clip faded in over the outgoing one", "seconds": 0.5, "ease": "linear",
          "incoming": { "keys": [ { "t": 0, "opacity": 0 }, { "t": 1, "opacity": 1 } ] } }
        """#

    let name: String
    let document: ResolvedSequence
    let times: [Double]
    let checks: [AgreementCheck]

    // MARK: - Initializer
    init(
        name: String,
        document: ResolvedSequence,
        times: [Double],
        checks: [AgreementCheck] = []
    ) {
        self.name = name
        self.document = document
        self.times = times
        self.checks = checks
    }

    // MARK: - Public
    // Every case, its media written into `directory`.
    static func all(in directory: TemporaryDirectory) async throws -> [AgreementCase] {
        let video = directory.file("code.mov")
        try await MovieWriter(size: Size(width: 160, height: 90), frameTimes: (0..<20).map { Double($0) / 10 }, end: 2)
            .write(to: video) { canvas, index in
                canvas.fill(red: 0.2, green: 0.5, blue: 0.3)
                canvas.drawCode(index * 37 + 5, bits: 6, side: 16)
            }
        let red = directory.file("red.png")
        try ColorImageWriter(size: Size(width: 160, height: 90), colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            .write(to: red, codeValues: [255, 0, 0])
        let pattern = directory.file("pattern.mov")
        try await MovieWriter(size: Size(width: 160, height: 90), frameTimes: (0..<20).map { Double($0) / 10 }, end: 2)
            .write(to: pattern) { canvas, _ in Self.drawStripes(on: canvas) }
        let detail = directory.file("detail.png")
        try ImageWriter(size: Size(width: 160, height: 90), opaque: true).write(to: detail) { Self.drawSquares(on: $0) }
        let white = directory.file("white.png")
        try ColorImageWriter(size: Size(width: 32, height: 32), colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            .write(to: white, codeValues: [255, 255, 255])
        let grid = directory.file("grid.png")
        try CornerPinStill.grid.write(to: grid)
        let resolver = try DocumentResolver(presets: ["filter/grey": Self.grey, "transition/fade": Self.fade])
        let title = #"{ "kind": "title", "text": "A caption", "style": "title", "at": [0, 2], "keyframes": [ { "at": 0, "position": [80, 60] }, { "at": 2, "position": [80, 30] } ] }"#

        return [
            AgreementCase(
                name: "a video under a moving title",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
                      "storyline": [ { "kind": "media", "media": "\#(video)", "in": 0, "out": 2, "connected": [ \#(title) ] } ] }
                    """#),
                times: [0.5, 1.3]
            ),
            AgreementCase(
                name: "a still scaled down, half transparent and screened over a video",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
                      "storyline": [ { "kind": "media", "media": "\#(video)", "in": 0, "out": 2,
                                       "connected": [ { "kind": "media", "media": "\#(red)", "at": [0, 2], "width": 64, "opacity": 0.5, "blend": "screen" } ] } ] }
                    """#),
                times: [0.5]
            ),
            AgreementCase(
                name: "shapes with a stroke, rounded corners, a shadow and a feathered mask",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
                      "storyline": [ { "kind": "solid", "color": "#203040", "duration": 2 } ],
                      "clips": [ { "kind": "rect", "area": [20, 10, 80, 50], "fill": "#E0A020", "stroke": { "width": 4, "paint": "#FFFFFF" }, "radius": 12, "shadow": true, "at": [0, 2] },
                                 { "kind": "rect", "area": [90, 20, 60, 60], "fill": "#30C0F0", "at": [0, 2], "mask": { "kind": "ellipse", "area": [0, 0, 160, 70], "feather": 8 } } ] }
                    """#),
                times: [0.5]
            ),
            AgreementCase(
                name: "an adjustment cut by a track matte over a still",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
                      "storyline": [ { "kind": "media", "media": "\#(red)", "duration": 1 } ],
                      "clips": [ { "id": "m", "kind": "rect", "area": [0, 0, 80, 90], "fill": "#FFFFFF", "at": [0, 1] },
                                 { "kind": "adjustment", "adjust": "mine/grey", "at": [0, 1], "trackMatte": { "clip": "m", "mode": "alpha" } } ] }
                    """#),
                times: [0.5]
            ),
            AgreementCase(
                name: "a crossfade between a detailed video and a detailed still",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "theme": { "defaults": { "transition": "mine/fade" } }, "format": { "size": [160, 90], "fps": 10 },
                      "storyline": [ { "kind": "media", "media": "\#(pattern)", "in": 0, "out": 1 }, { "kind": "media", "media": "\#(detail)", "duration": 1 } ] }
                    """#),
                times: [0.8, 1.0, 1.2],
                checks: [.mix(outgoing: 0.2, incoming: 1.8, at: 1.0)]
            ),
            AgreementCase(
                name: "a detailed still scaled by 0.625 and by 1.375 over a video",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
                      "storyline": [ { "kind": "media", "media": "\#(pattern)", "in": 0, "out": 2,
                                       "connected": [ { "kind": "media", "media": "\#(detail)", "at": [0, 2], "width": 100, "position": [55.375, 40.625] },
                                                      { "kind": "media", "media": "\#(detail)", "at": [0, 2], "width": 220, "position": [150.25, 70.75] } ] } ] }
                    """#),
                times: [0.5]
            ),
            AgreementCase(
                name: "a detailed still turned by 17 degrees over a video",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
                      "storyline": [ { "kind": "media", "media": "\#(pattern)", "in": 0, "out": 2,
                                       "connected": [ { "kind": "media", "media": "\#(detail)", "at": [0, 2], "width": 100, "position": [80, 45], "rotation": 17 } ] } ] }
                    """#),
                times: [0.5]
            ),
            AgreementCase(
                name: "hard edges of a shape and of a picture at sub-pixel positions",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [160, 90], "fps": 10, "background": "#00000000" },
                      "storyline": [ { "kind": "solid", "color": "#00000000", "duration": 1 } ],
                      "clips": [ { "kind": "rect", "area": [20.375, 10.625, 50.25, 30.5], "fill": "#FFFFFF", "at": [0, 1] },
                                 { "kind": "media", "media": "\#(white)", "at": [0, 1], "width": 40, "position": [110.375, 60.625] } ] }
                    """#),
                times: [0.5],
                checks: [
                    .edge(EdgeProbe(name: "the shape's left edge at 20.375", isVertical: true, inside: 30, outside: 15, along: 20..<30)),
                    .edge(EdgeProbe(name: "the shape's right edge at 70.625", isVertical: true, inside: 60, outside: 75, along: 20..<30)),
                    .edge(EdgeProbe(name: "the shape's top edge at 10.625", isVertical: false, inside: 25, outside: 5, along: 30..<60)),
                    .edge(EdgeProbe(name: "the picture's left edge at 90.375", isVertical: true, inside: 100, outside: 85, along: 50..<70)),
                    .edge(EdgeProbe(name: "the picture's right edge at 130.375", isVertical: true, inside: 120, outside: 135, along: 50..<70)),
                    .edge(EdgeProbe(name: "the picture's top edge at 40.625", isVertical: false, inside: 60, outside: 35, along: 100..<120)),
                    .edge(EdgeProbe(name: "the picture's bottom edge at 80.625", isVertical: false, inside: 70, outside: 85, along: 100..<120))
                ]
            ),
            AgreementCase(
                name: "a grid carried onto a corner pin",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [1024, 1024], "fps": 10, "background": "#00000000", "colorSpace": "srgb" },
                      "storyline": [ { "kind": "media", "media": "\#(grid)", "duration": 1, "cornerPin": [[190, 164], [840, 124], [880, 854], [150, 904]] } ] }
                    """#),
                times: [0.5]
            ),
            AgreementCase(
                name: "a sliding rectangle with motion blur",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [400, 20], "fps": 25 },
                      "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 } ],
                      "clips": [ { "kind": "rect", "fill": "#FFFFFF", "at": [0, 2], "width": 40, "height": 20, "motionBlur": true,
                                   "keyframes": [ { "at": 0, "position": [60, 10], "ease": "linear" }, { "at": 0.2, "position": [380, 10] } ] } ] }
                    """#),
                times: [0.08]
            ),
            AgreementCase(
                name: "a video under a moving title composited in the linear form",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "format": { "size": [160, 90], "fps": 10, "colorSpace": "display-p3", "compositing": "linear" },
                      "storyline": [ { "kind": "media", "media": "\#(video)", "in": 0, "out": 2, "connected": [ \#(title) ] } ] }
                    """#),
                times: [0.5]
            )
        ]
    }

    // MARK: - Private
    // Diagonal stripes 6 px wide in three colours, under a code of white and black squares.
    private static func drawStripes(on canvas: Canvas) {
        let colors: [[Double]] = [[40, 120, 200], [230, 200, 60], [150, 30, 90]]
        for x in 0..<160 {
            for y in stride(from: 0, to: 90, by: 2) {
                let color = colors[((x + y) / 6) % colors.count]
                let line = Rectangle(x: Double(x), y: Double(y), width: 1, height: 2)
                canvas.fill(line, red: color[0], green: color[1], blue: color[2])
            }
        }
        canvas.drawCode(45, bits: 6, side: 10)
    }

    // Squares of 5 px, each of its own colour.
    private static func drawSquares(on canvas: Canvas) {
        for column in 0..<32 {
            for row in 0..<18 {
                let square = Rectangle(x: Double(column * 5), y: Double(row * 5), width: 5, height: 5)
                canvas.fill(
                    square,
                    red: Double((column * 53 + row * 29) % 256),
                    green: Double((column * 17 + row * 71) % 256),
                    blue: Double((column * 91 + row * 13) % 256)
                )
            }
        }
    }
}
