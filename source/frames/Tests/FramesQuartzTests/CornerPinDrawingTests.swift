//
//  CornerPinDrawingTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import Testing

@Suite("Corner pin drawing Tests")
struct CornerPinDrawingTests {
    // MARK: - Property
    private static let clear = Color(written: "#00000000")
    private static let white = Color(written: "#FFFFFF")
    private static let red = Color(written: "#FF0000")
    private static let green = Color(written: "#00FF00")
    private static let blue = Color(written: "#0000FF")
    private static let box = Rectangle(x: 0, y: 0, width: 64, height: 64)
    private static let cornerPin = Quad(
        topLeft: Point(x: 30, y: 20),
        topRight: Point(x: 100, y: 30),
        bottomRight: Point(x: 110, y: 110),
        bottomLeft: Point(x: 20, y: 100)
    )

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())
    // A 16-bit output reproduces an 8-bit colour to well within one step.
    private let tolerance = 1.0 / 255

    // MARK: - Initializer
    // MARK: - Test
    @Test("a picture with a corner pin lands the corners of its destination on the four points")
    func landsCornersOnPoints() throws {
        // Given
        let picture = pinned(list(size: 64, items: [fill(Self.box, Self.red)]), destination: Self.box)

        // When
        let bitmap = try sut.frame(of: output(DisplayItem(content: .picture(picture))))

        // Then
        let centre = Self.cornerPin.centroid
        expect(bitmap, at: centre, equals: [1, 0, 0, 1])
        for corner in Self.cornerPin.corners {
            let length = ((centre.x - corner.x) * (centre.x - corner.x) + (centre.y - corner.y) * (centre.y - corner.y))
                .squareRoot()
            let inward = Point(x: (centre.x - corner.x) / length * 5, y: (centre.y - corner.y) / length * 5)
            expect(bitmap, at: Point(x: corner.x + inward.x, y: corner.y + inward.y), equals: [1, 0, 0, 1])
            expect(bitmap, at: Point(x: corner.x - inward.x, y: corner.y - inward.y), equals: [1, 1, 1, 1])
        }
    }

    @Test("a picture with a corner pin is carried by its item's transform after the corner pin")
    func carriesCornerPinByTransform() throws {
        // Given
        let picture = pinned(list(size: 64, items: [fill(Self.box, Self.red)]), destination: Self.box)
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 0.5, b: 0, c: 0, d: 0.5, tx: 64, ty: 0),
            content: .picture(picture)
        )

        // When
        let bitmap = try sut.frame(of: output(item))

        // Then
        let centre = Self.cornerPin.centroid
        expect(bitmap, at: Point(x: centre.x / 2 + 64, y: centre.y / 2), equals: [1, 0, 0, 1])
        expect(bitmap, at: centre, equals: [1, 1, 1, 1])
    }

    @Test("an item's mask and opacity cut the picture after its corner pin, in output pixels")
    func cutsCarriedPicture() throws {
        // Given
        let picture = pinned(list(size: 64, items: [fill(Self.box, Self.red)]), destination: Self.box)
        let mask = ItemMask(
            geometry: .rect(Rectangle(x: 0, y: 0, width: 64, height: 128), radius: 0),
            transform: .identity,
            feather: 0,
            isInverted: false,
            mode: .add
        )
        let item = DisplayItem(opacity: 0.5, mask: [mask], content: .picture(picture))

        // When
        let bitmap = try sut.frame(of: output(item))

        // Then
        expect(bitmap, at: Point(x: 40, y: 65), equals: [1, 0.5, 0.5, 1])
        expect(bitmap, at: Point(x: 90, y: 65), equals: [1, 1, 1, 1])
    }

    @Test("a list carried larger by its corner pin is drawn at the scale the corner pin stretches it, so its edges stay sharp")
    func drawsStretchedListSharp() throws {
        // Given
        let halves = list(
            size: 8,
            items: [
                fill(Rectangle(x: 0, y: 0, width: 4, height: 8), Self.red),
                fill(Rectangle(x: 4, y: 0, width: 4, height: 8), Self.blue)
            ]
        )
        let cornerPin = Quad(
            topLeft: Point(x: 8, y: 8),
            topRight: Point(x: 120, y: 16),
            bottomRight: Point(x: 120, y: 112),
            bottomLeft: Point(x: 8, y: 120)
        )
        let destination = Rectangle(x: 0, y: 0, width: 8, height: 8)
        let picture = pinned(halves, destination: destination, cornerPin: cornerPin)

        // When
        let bitmap = try sut.frame(of: output(DisplayItem(content: .picture(picture))))

        // Then
        // The halves meet where the corner pin carries the box's middle, about 15 output pixels a list pixel.
        let map = try #require(Homography(from: Quad(destination), to: cornerPin))
        let middle = try #require(map.apply(to: Point(x: 4, y: 4)))
        expect(bitmap, at: Point(x: middle.x - 3, y: middle.y), equals: [1, 0, 0, 1], tolerance: 0.02)
        expect(bitmap, at: Point(x: middle.x + 3, y: middle.y), equals: [0, 0, 1, 1], tolerance: 0.02)
    }

    @Test("a picture with a corner pin shows its whole list, the part outside its region carried past its destination")
    func showsWholeList() throws {
        // Given
        let nested = list(
            size: 64,
            items: [
                fill(Rectangle(x: 0, y: 0, width: 16, height: 64), Self.green),
                fill(Rectangle(x: 16, y: 0, width: 48, height: 64), Self.red)
            ]
        )
        let destination = Rectangle(x: 0, y: 0, width: 48, height: 64)
        let picture = PictureItem(
            source: .displayList(nested),
            rectangle: Rectangle(x: 16, y: 0, width: 48, height: 64),
            destination: destination,
            cornerPin: Self.cornerPin
        )

        // When
        let bitmap = try sut.frame(of: output(DisplayItem(content: .picture(picture))))

        // Then
        // The region's left edge is the destination's, so the list's green part lies at x -16 to 0 of the item.
        let map = try #require(Homography(from: Quad(destination), to: Self.cornerPin))
        expect(bitmap, at: try #require(map.apply(to: Point(x: -8, y: 32))), equals: [0, 1, 0, 1])
        expect(bitmap, at: try #require(map.apply(to: Point(x: 24, y: 32))), equals: [1, 0, 0, 1])
    }

    // MARK: - Private
    private func pinned(
        _ list: DisplayList,
        destination: Rectangle,
        cornerPin: Quad = Self.cornerPin
    ) -> PictureItem {
        PictureItem(source: .displayList(list), rectangle: nil, destination: destination, cornerPin: cornerPin)
    }

    private func fill(
        _ rectangle: Rectangle,
        _ color: Color
    ) -> DisplayItem {
        DisplayItem(content: .path(PathItem(filling: rectangle, color: color)))
    }

    private func list(
        size: Double,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: Size(width: size, height: size), background: Self.clear, seed: 0, items: items)
    }

    // A 128 x 128 white frame holding the item.
    private func output(_ item: DisplayItem) -> DisplayList {
        DisplayList(size: Size(width: 128, height: 128), background: Self.white, seed: 0, items: [item])
    }

    // The pixel that holds the point.
    private func expect(
        _ bitmap: Bitmap,
        at point: Point,
        equals expected: [Double],
        tolerance: Double? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let pixel = bitmap.pixel(x: Int(point.x.rounded(.down)), y: Int(point.y.rounded(.down)))
        #expect(
            zip(pixel, expected).allSatisfy { abs($0 - $1) <= tolerance ?? self.tolerance },
            "\(pixel) at \(point) is not \(expected)",
            sourceLocation: sourceLocation
        )
    }
}
