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

// A resolved document and the times of the frames two renderers are compared on, one for each kind of item and
// operation a renderer draws: a video under a moving title, a scaled still with opacity and a blend mode, shapes with
// strokes, rounded corners, a shadow and a feathered mask, an adjustment cut by a track matte, a crossfade, a corner
// pin, motion blur, and a list composited in the linear form.
struct AgreementCase {
    // MARK: - Property
    private static let grey = #"{ "description": "every colour turned to its grey", "ops": [ { "kind": "saturation", "amount": 0 } ] }"#
    private static let fade = #"{ "description": "fades", "seconds": 0.5 }"#

    let name: String
    let document: ResolvedSequence
    let times: [Double]

    // MARK: - Initializer
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
                name: "a crossfade between a video and a still",
                document: try resolver.resolve(#"""
                    { "kind": "sequence", "theme": { "defaults": { "transition": "mine/fade" } }, "format": { "size": [160, 90], "fps": 10 },
                      "storyline": [ { "kind": "media", "media": "\#(video)", "in": 0, "out": 1 }, { "kind": "media", "media": "\#(red)", "duration": 1 } ] }
                    """#),
                times: [0.9, 1.0, 1.1]
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
}
