//
//  GradientDrawerTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames
import FramesTestMedia
import FramesAVFoundation
@testable import FramesQuartz
import Testing

// Gradient paints drawn on a transparent 100 x 100 frame and read back as premultiplied components at pixel centres,
// against the colour `Gradient.channels(at:)` gives at the centre's position, within 0.02: Core Graphics samples the
// shading's function along the ramp, which moves a colour by up to about half a pixel's position.
@Suite("GradientDrawer Tests")
struct GradientDrawerTests {
    // MARK: - Property
    private static let tolerance = 0.02

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    // MARK: - Initializer
    // MARK: - Test
    @Test("a linear fill takes the ramp's colour at each point's projection, and holds its end colours past its ends")
    func fillsLinearGradient() throws {
        // Given
        let gradient = Gradient(
            shape: .linear(from: Point(x: 20, y: 0), to: Point(x: 80, y: 0)),
            stops: stops([(0, "#FF0000"), (0.5, "#00FF0080"), (1, "#0000FF")])
        )
        let path = filled(.rect(Rectangle(x: 0, y: 0, width: 100, height: 100), radius: 0), with: .gradient(gradient))

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        for x in [2, 25, 40, 50, 65, 97] {
            expect(bitmap, x, 50, gradient.channels(at: (Double(x) + 0.5 - 20) / 60))
        }
        expect(bitmap, 2, 50, [1, 0, 0, 1])
        expect(bitmap, 97, 50, [0, 0, 1, 1])
    }

    @Test(
        "a gradient interpolates on the encoded form under either compositing, its stops above 1 kept",
        arguments: Compositing.allCases
    )
    func interpolatesOnEncodedForm(compositing: Compositing) throws {
        // Given
        // color(srgb-linear 4 4 4) is the encoded 1.8248, so halfway from black it is the encoded 0.9124.
        let gradient = Gradient(
            shape: .linear(from: Point(x: 0, y: 0), to: Point(x: 100, y: 0)),
            stops: stops([(0, "#000000"), (1, "color(srgb-linear 4 4 4)")])
        )
        let path = filled(.rect(Rectangle(x: 0, y: 0, width: 100, height: 100), radius: 0), with: .gradient(gradient))
        let list = DisplayList(
            size: Size(width: 100, height: 100),
            background: Color(written: "#00000000"),
            compositing: compositing,
            seed: 0,
            items: [DisplayItem(content: .path(path))]
        )

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        let middle = bitmap.pixel(x: 49, y: 50)[0] / 2 + bitmap.pixel(x: 50, y: 50)[0] / 2
        #expect(abs(middle - 0.9124) < 0.005, "\(middle)")
        #expect(abs(bitmap.pixel(x: 99, y: 50)[0] - 1.8248 * 199 / 200) < 0.01)
    }

    @Test("two stops at one offset make a hard edge, the later stop's colour from there on")
    func drawsHardEdge() throws {
        // Given
        let gradient = Gradient(
            shape: .linear(from: Point(x: 0, y: 0), to: Point(x: 100, y: 0)),
            stops: stops([(0, "#FF0000"), (0.5, "#FF0000"), (0.5, "#0000FF"), (1, "#0000FF")])
        )
        let path = filled(.rect(Rectangle(x: 0, y: 0, width: 100, height: 100), radius: 0), with: .gradient(gradient))

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, 48, 50, [1, 0, 0, 1])
        expect(bitmap, 51, 50, [0, 0, 1, 1])
    }

    @Test("a radial gradient whose radius is the distance to the farthest corner of a wide box reaches its last colour at every corner")
    func reachesEveryCorner() throws {
        // Given
        // A 100 by 40 box centred on (50, 50): its corners lie 53.85 from the centre.
        let radius = (50.0 * 50 + 20 * 20).squareRoot()
        let gradient = Gradient(
            shape: .radial(center: Point(x: 50, y: 50), radius: radius),
            stops: stops([(0, "#FFFFFF"), (1, "#000000")])
        )
        let path = filled(.rect(Rectangle(x: 0, y: 30, width: 100, height: 40), radius: 0), with: .gradient(gradient))

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        for (x, y) in [(49, 49), (75, 50), (50, 31), (0, 30), (99, 30), (0, 69), (99, 69)] {
            let distance = ((Double(x) + 0.5 - 50) * (Double(x) + 0.5 - 50) + (Double(y) + 0.5 - 50) * (Double(y) + 0.5 - 50))
                .squareRoot()
            expect(bitmap, x, y, gradient.channels(at: distance / radius))
        }
        for (x, y) in [(0, 30), (99, 30), (0, 69), (99, 69)] {
            #expect(bitmap.pixel(x: x, y: y)[0] < 0.03, "corner (\(x), \(y))")
        }
        #expect(bitmap.pixel(x: 50, y: 10)[3] == 0)
    }

    @Test("a radial gradient under a transform that scales its axes apart is drawn as an ellipse")
    func drawsRadialAsEllipse() throws {
        // Given
        // A hard edge at radius 10 about (25, 50) at [2, 1] is an ellipse about (50, 50), 20 across x and 10 across y.
        let gradient = Gradient(
            shape: .radial(center: Point(x: 25, y: 50), radius: 20),
            stops: stops([(0, "#000000"), (0.5, "#000000"), (0.5, "#00000000"), (1, "#00000000")])
        )
        let path = filled(.rect(Rectangle(x: 0, y: 0, width: 50, height: 100), radius: 0), with: .gradient(gradient))
        let item = DisplayItem(transform: AffineTransform(a: 2, b: 0, c: 0, d: 1, tx: 0, ty: 0), content: .path(path))
        let list = DisplayList(size: Size(width: 100, height: 100), background: Color(written: "#00000000"), seed: 0, items: [item])

        // When
        let bitmap = try sut.frame(of: list)

        // Then
        for (x, y, isInked) in [(66, 50, true), (50, 56, true), (72, 50, false), (50, 62, false), (64, 58, false)] {
            let alpha = bitmap.pixel(x: x, y: y)[3]
            #expect(isInked ? alpha > 0.99 : alpha < 0.01, "pixel (\(x), \(y)) has alpha \(alpha)")
        }
    }

    @Test("a vignette from #FFFFFF00 to black draws the same pixels as one from #00000000, with no grey band")
    func drawsTransparentStopsAlike() throws {
        // Given
        let vignette = { (clear: String) in
            self.filled(.rect(Rectangle(x: 0, y: 0, width: 100, height: 100), radius: 0), with: .gradient(Gradient(
                shape: .radial(center: Point(x: 50, y: 50), radius: 50 * 2.0.squareRoot()),
                stops: self.stops([(0, clear), (1, "#000000")])
            )))
        }

        // When
        let white = try sut.frame(of: list([vignette("#FFFFFF00")]))
        let black = try sut.frame(of: list([vignette("#00000000")]))

        // Then
        for y in stride(from: 0, to: 100, by: 7) {
            for x in stride(from: 0, to: 100, by: 7) {
                #expect(white.components(x: x, y: y) == black.components(x: x, y: y), "pixel (\(x), \(y))")
                #expect(white.pixel(x: x, y: y)[0] < 1e-3, "pixel (\(x), \(y)) is grey")
            }
        }
    }

    @Test("a linear gradient whose ends are one point paints its last stop's colour over the fill")
    func paintsDegenerateLastColor() throws {
        // Given
        let gradient = Gradient(
            shape: .linear(from: Point(x: 50, y: 50), to: Point(x: 50, y: 50)),
            stops: stops([(0, "#FF0000"), (1, "#0000FF80")])
        )
        let path = filled(.rect(Rectangle(x: 20, y: 20, width: 60, height: 60), radius: 0), with: .gradient(gradient))

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        let half = 128.0 / 255
        for (x, y) in [(21, 21), (50, 50), (78, 78)] {
            expect(bitmap, x, y, [0, 0, 1, half])
        }
        #expect(bitmap.pixel(x: 10, y: 10)[3] == 0)
    }

    @Test("a stroke's gradient paints the line and its arrowhead with the colour where each lies")
    func paintsStrokeAndArrowhead() throws {
        // Given
        // A 4 wide line from (10, 50) to (90, 50), its head from x = 74.
        let gradient = Gradient(
            shape: .linear(from: Point(x: 0, y: 0), to: Point(x: 100, y: 0)),
            stops: stops([(0, "#FF0000"), (1, "#0000FF")])
        )
        let path = PathItem(
            geometry: .polyline([Point(x: 10, y: 50), Point(x: 90, y: 50)], isClosed: false),
            fill: nil,
            stroke: PathStroke(width: 4, paint: .gradient(gradient), join: .miter, cap: .butt, start: .none, end: .arrow)
        )

        // When
        let bitmap = try sut.frame(of: list([path]))

        // Then
        expect(bitmap, 30, 50, gradient.channels(at: 0.305))
        expect(bitmap, 80, 50, gradient.channels(at: 0.805))
        // Above the line's edge at y = 48, inside the head.
        expect(bitmap, 80, 47, gradient.channels(at: 0.805))
        #expect(bitmap.pixel(x: 30, y: 45)[3] == 0)
    }

    // MARK: - Private
    private func list(_ paths: [PathItem]) -> DisplayList {
        DisplayList(
            size: Size(width: 100, height: 100),
            background: Color(written: "#00000000"),
            seed: 0,
            items: paths.map { DisplayItem(content: .path($0)) }
        )
    }

    private func filled(
        _ geometry: PathGeometry,
        with paint: Paint
    ) -> PathItem {
        PathItem(geometry: geometry, fill: paint, stroke: nil)
    }

    private func stops(_ stops: [(Double, String)]) -> [GradientStop] {
        stops.map { offset, color in GradientStop(offset: offset, color: Color(written: color)) }
    }

    // The pixel's premultiplied components against straight `channels`.
    private func expect(
        _ bitmap: Bitmap,
        _ x: Int,
        _ y: Int,
        _ channels: [Double],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let pixel = bitmap.pixel(x: x, y: y)
        let expected = [channels[0] * channels[3], channels[1] * channels[3], channels[2] * channels[3], channels[3]]
        #expect(
            zip(pixel, expected).allSatisfy { abs($0 - $1) < Self.tolerance },
            "pixel (\(x), \(y)) is \(pixel), expected \(expected)",
            sourceLocation: sourceLocation
        )
    }
}
