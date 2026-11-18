//
//  TrackMatteDrawerTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import Testing

@Suite("TrackMatteDrawer Tests")
struct TrackMatteDrawerTests {
    // MARK: - Property
    // The matte value is stored in eight bits before the item is clipped by it.
    private static let tolerance = 1.0 / 255
    private static let size = 40.0

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    private let white = Color(written: "#FFFFFF")
    private let top = Rectangle(x: 0, y: 0, width: 40, height: 20)
    private let left = Rectangle(x: 0, y: 0, width: 20, height: 40)
    private let bottomLeft = Rectangle(x: 0, y: 20, width: 20, height: 20)

    // MARK: - Initializer
    // MARK: - Test
    @Test("an alpha matte multiplies the item's alpha by its source's alpha, where the source is drawn and not elsewhere")
    func multipliesByAlpha() throws {
        // Given
        let source = [fill(top, color: "#00000080")]

        // When
        let bitmap = try sut.frame(of: list(matte: ItemTrackMatte(source: list(source), mode: .alpha, isInverted: false)))

        // Then
        expect(alpha(of: bitmap, x: 20, y: 5), equals: 128.0 / 255)
        expect(alpha(of: bitmap, x: 20, y: 19), equals: 128.0 / 255)
        expect(alpha(of: bitmap, x: 20, y: 20), equals: 0)
        expect(alpha(of: bitmap, x: 20, y: 35), equals: 0)
    }

    @Test("a luma matte takes the luma of its unpremultiplied sRGB-encoded values times its alpha, and its transparent part as black")
    func multipliesByLuma() throws {
        // Given
        let source = [fill(top, color: "#808080FF"), fill(bottomLeft, color: "#FF000080")]

        // When
        let bitmap = try sut.frame(of: list(matte: ItemTrackMatte(source: list(source), mode: .luma, isInverted: false)))

        // Then
        expect(alpha(of: bitmap, x: 20, y: 10), equals: 128.0 / 255)
        expect(alpha(of: bitmap, x: 10, y: 30), equals: 0.2126 * 128 / 255)
        expect(alpha(of: bitmap, x: 30, y: 30), equals: 0)
    }

    @Test("an inverted matte multiplies by 1 minus its value, so its transparent part shows the item whole in both modes")
    func invertsMatte() throws {
        // Given
        let source = [fill(top, color: "#80808080")]

        // When
        let alphaMatte = try sut.frame(of: list(matte: ItemTrackMatte(source: list(source), mode: .alpha, isInverted: true)))
        let lumaMatte = try sut.frame(of: list(matte: ItemTrackMatte(source: list(source), mode: .luma, isInverted: true)))

        // Then
        expect(alpha(of: alphaMatte, x: 20, y: 10), equals: 1 - 128.0 / 255)
        expect(alpha(of: alphaMatte, x: 20, y: 30), equals: 1)
        expect(alpha(of: lumaMatte, x: 20, y: 10), equals: 1 - (128.0 / 255) * (128.0 / 255))
        expect(alpha(of: lumaMatte, x: 20, y: 30), equals: 1)
    }

    @Test("the matte multiplies the mask's result and the item's opacity once each, so no alpha doubles")
    func multipliesMaskMatteAndOpacity() throws {
        // Given
        let matte = ItemTrackMatte(source: list([fill(top, color: "#000000FF")]), mode: .alpha, isInverted: false)
        let mask = ItemMask(geometry: .rect(left, radius: 0), transform: .identity, feather: 0, isInverted: false, mode: .add)
        let item = DisplayItem(
            opacity: 0.5,
            mask: [mask],
            trackMatte: matte,
            content: .path(PathItem(filling: frame, color: white))
        )

        // When
        let bitmap = try sut.frame(of: list([item]))

        // Then
        expect(alpha(of: bitmap, x: 10, y: 10), equals: 0.5)
        expect(alpha(of: bitmap, x: 30, y: 10), equals: 0)
        expect(alpha(of: bitmap, x: 10, y: 30), equals: 0)
    }

    @Test("a shadow is cast from the alpha the matte leaves, so it falls only below what the matte shows")
    func castsShadowAfterMatte() throws {
        // Given
        let matte = ItemTrackMatte(source: list([fill(top, color: "#000000FF")]), mode: .alpha, isInverted: false)
        let shadow = DropShadow(radius: 0, offset: Point(x: 10, y: 0), color: Color(written: "#000000FF"))
        let path = PathItem(geometry: .rect(left, radius: 0), fill: white, stroke: nil, shadow: shadow)
        let item = DisplayItem(trackMatte: matte, content: .path(path))

        // When
        let bitmap = try sut.frame(of: list([item]))

        // Then
        // The shadow shows right of the fill, from x 20 to 30, where the matte keeps the fill above y 20.
        expect(alpha(of: bitmap, x: 25, y: 10), equals: 1)
        #expect(bitmap.pixel(x: 25, y: 10)[0] < Self.tolerance)
        expect(alpha(of: bitmap, x: 25, y: 30), equals: 0)
        expect(alpha(of: bitmap, x: 10, y: 30), equals: 0)
    }

    // MARK: - Private
    private var frame: Rectangle {
        Rectangle(x: 0, y: 0, width: Self.size, height: Self.size)
    }

    private func fill(
        _ rectangle: Rectangle,
        color: String
    ) -> DisplayItem {
        DisplayItem(content: .path(PathItem(filling: rectangle, color: Color(written: color))))
    }

    // A transparent list of the frame's size.
    private func list(_ items: [DisplayItem]) -> DisplayList {
        DisplayList(
            size: Size(width: Self.size, height: Self.size),
            background: Color(written: "#00000000"),
            seed: 0,
            items: items
        )
    }

    // A white fill over the whole frame, so each pixel's alpha is the matte's value.
    private func list(matte: ItemTrackMatte) -> DisplayList {
        list([DisplayItem(trackMatte: matte, content: .path(PathItem(filling: frame, color: white)))])
    }

    private func alpha(
        of bitmap: Bitmap,
        x: Int,
        y: Int
    ) -> Double {
        bitmap.pixel(x: x, y: y)[3]
    }

    private func expect(
        _ value: Double,
        equals expected: Double,
        within tolerance: Double = Self.tolerance,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(value - expected) <= tolerance, "\(value) is not \(expected)", sourceLocation: sourceLocation)
    }
}
