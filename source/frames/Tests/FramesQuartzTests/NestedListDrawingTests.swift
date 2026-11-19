//
//  NestedListDrawingTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Foundation
import Frames
import FramesAVFoundation
@testable import FramesQuartz
import Testing

@Suite("Nested list drawing Tests")
struct NestedListDrawingTests {
    // MARK: - Property
    private static let clear = Color(written: "#00000000")
    private static let white = Color(written: "#FFFFFF")
    private static let black = Color(written: "#000000")

    private let sut = QuartzRenderer(decoder: AVFoundationDecoder())

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a nested list shown larger than its size matches its items drawn in place, where drawing it at its size and scaling it up is soft",
        arguments: [
            Frames.AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0),
            Frames.AffineTransform(a: 3, b: 0, c: 0, d: 3, tx: -12, ty: -9),
            Frames.AffineTransform(a: 3, b: 0, c: 0, d: 1.5, tx: -6, ty: 4)
        ]
    )
    func drawsNestedListAtShownScale(transform: Frames.AffineTransform) throws {
        // Given
        let scene = scene()
        let shown = DisplayItem(transform: transform, content: .picture(picture(of: scene)))
        let inPlace = scene.items.map { item in moved(item, by: transform) }

        // When
        let nested = try sut.frame(of: list(size: 40, items: [shown]))
        let drawn = try sut.frame(of: list(size: 40, items: inPlace))
        let scaledUp = try scaledUp(scene, by: transform, size: 40)

        // Then
        #expect(difference(nested, drawn).largest < 0.03)
        #expect(difference(scaledUp, drawn).largest > 0.2)
    }

    @Test("a nested list turned and scaled is closer to its items drawn in place than drawing it at its size")
    func drawsTurnedNestedList() throws {
        // Given
        // A sixth of a turn at scale 2, about (20, 20).
        let angle = Double.pi / 6
        let transform = Frames.AffineTransform(
            a: 2 * cos(angle),
            b: 2 * sin(angle),
            c: -2 * sin(angle),
            d: 2 * cos(angle),
            tx: 20 - 2 * (10 * cos(angle) - 10 * sin(angle)),
            ty: 20 - 2 * (10 * sin(angle) + 10 * cos(angle))
        )
        let scene = scene()
        let shown = DisplayItem(transform: transform, content: .picture(picture(of: scene)))
        let inPlace = scene.items.map { item in moved(item, by: transform) }

        // When
        let nested = try sut.frame(of: list(size: 40, items: [shown]))
        let drawn = try sut.frame(of: list(size: 40, items: inPlace))
        let scaledUp = try scaledUp(scene, by: transform, size: 40)

        // Then
        // The raster is drawn upright at scale 2 and turned when it is drawn, so its edges are resampled once.
        let sharp = difference(nested, drawn)
        let soft = difference(scaledUp, drawn)
        #expect(sharp.mean < soft.mean / 2)
        #expect(sharp.largest < 0.45)
        #expect(soft.largest > 0.6)
    }

    @Test("a nested list's shadow, blur filter, adjustment, feathered mask and track matte shown at 2x, averaged down to 1x, match it shown at 1x")
    func keepsLookAtShownScale() throws {
        // Given
        let scene = effects()
        let once = DisplayItem(content: .picture(picture(of: scene)))
        let twice = DisplayItem(
            transform: Frames.AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0),
            content: .picture(picture(of: scene))
        )

        // When
        let small = try sut.frame(of: list(size: 40, items: [once]))
        let large = try sut.frame(of: list(size: 80, items: [twice]))

        // Then
        let averaged = halved(large)
        var largest = 0.0
        var total = 0.0
        for y in 0..<40 {
            for x in 0..<40 {
                for (left, right) in zip(averaged[y * 40 + x], small.pixel(x: x, y: y)) {
                    largest = max(largest, abs(left - right))
                    total += abs(left - right)
                }
            }
        }
        #expect(largest < 0.12)
        #expect(total / (40 * 40 * 4) < 0.006)
    }

    @Test("a shadow cast into the frame by the part of a nested list outside it is kept")
    func castsShadowFromOutsideFrame() throws {
        // Given
        // At scale 2 the square lies at (28, 8, 8, 8), past the frame's right edge, and its shadow 16 to the left.
        let square = PathItem(filling: Rectangle(x: 14, y: 4, width: 4, height: 4), color: Self.white)
        let scene = DisplayList(size: Size(width: 20, height: 20), background: Self.clear, seed: 0, items: [
            DisplayItem(content: .path(square))
        ])
        let picture = PictureItem(
            source: .displayList(scene),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 20, height: 20),
            shadow: DropShadow(radius: 0, offset: Point(x: -8, y: 0), color: Self.black)
        )
        let item = DisplayItem(transform: Frames.AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 0, ty: 0), content: .picture(picture))

        // When
        let bitmap = try sut.frame(of: list(size: 20, items: [item]))

        // Then
        #expect(bitmap.pixel(x: 15, y: 12) == [0, 0, 0, 1])
        #expect(bitmap.pixel(x: 15, y: 4)[3] == 0)
    }

    @Test("a nested list shown at a huge scale is drawn only where it lands in the frame and keeps its colours")
    func drawsHugeScaleInFrame() throws {
        // Given
        // At scale 10000 the frame shows the list's (50, 50, 0.0064, 0.0048), the left half red and the right half blue.
        let scene = DisplayList(size: Size(width: 100, height: 100), background: Self.clear, seed: 0, items: [
            DisplayItem(content: .path(PathItem(
                filling: Rectangle(x: 0, y: 0, width: 50.0032, height: 100),
                color: Color(written: "#FF0000")
            ))),
            DisplayItem(content: .path(PathItem(
                filling: Rectangle(x: 50.0032, y: 0, width: 49.9968, height: 100),
                color: Color(written: "#0000FF")
            )))
        ])
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 10_000, b: 0, c: 0, d: 10_000, tx: -500_000, ty: -500_000),
            content: .picture(picture(of: scene))
        )

        // When
        let bitmap = try sut.frame(of: DisplayList(
            size: Size(width: 64, height: 48),
            background: Self.white,
            seed: 0,
            items: [item]
        ))

        // Then
        #expect(bitmap.pixel(x: 31, y: 24) == [1, 0, 0, 1])
        #expect(bitmap.pixel(x: 32, y: 24) == [0, 0, 1, 1])
    }

    @Test(
        "a blur adjustment inside a compound clip that crosses the frame edge, at any depth, matches the compound clip drawn uncut",
        arguments: [1, 2, 3]
    )
    func blursAcrossFrameEdge(depth: Int) throws {
        // Given
        let scene = (1..<depth).reduce(blurredEdge()) { inner, _ in
            list(size: 40, items: [DisplayItem(content: .picture(picture(of: inner)))])
        }
        // The frame's right edge cuts the list at its x = 15, a pixel left of where black meets white.
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 25, ty: 0),
            content: .picture(picture(of: scene))
        )

        // When
        let cut = try sut.frame(of: list(size: 40, items: [item]))
        let uncut = try sut.frame(of: list(width: 80, height: 40, items: [item]))

        // Then
        #expect(difference(cut, uncut).largest < 0.03)
    }

    @Test("a luma track matte whose source holds a blur adjustment, inside a compound clip that crosses the frame edge, matches the compound clip drawn uncut")
    func blursTrackMatteAcrossFrameEdge() throws {
        // Given
        let matteSource = blurredEdge()
        let matted = PathItem(filling: Rectangle(x: 0, y: 0, width: 40, height: 40), color: Self.white)
        let scene = list(size: 40, items: [
            DisplayItem(
                trackMatte: ItemTrackMatte(source: matteSource, mode: .luma, isInverted: false),
                content: .path(matted)
            )
        ])
        let item = DisplayItem(
            transform: Frames.AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 25, ty: 0),
            content: .picture(picture(of: scene))
        )

        // When
        let cut = try sut.frame(of: list(size: 40, items: [item]))
        let uncut = try sut.frame(of: list(width: 80, height: 40, items: [item]))

        // Then
        #expect(difference(cut, uncut).largest < 0.03)
    }

    @Test("a blur adjustment inside a cropped compound clip matches the compound clip drawn whole and cut to the same rectangle")
    func blursAcrossCrop() throws {
        // Given
        let scene = blurredEdge()
        let shown = Rectangle(x: 0, y: 0, width: 15, height: 40)
        let transform = Frames.AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 10, ty: 0)
        let cropped = DisplayItem(
            transform: transform,
            content: .picture(PictureItem(source: .displayList(scene), rectangle: shown, destination: shown))
        )
        let revealed = DisplayItem(transform: transform, reveal: shown, content: .picture(picture(of: scene)))

        // When
        let cut = try sut.frame(of: list(size: 40, items: [cropped]))
        let whole = try sut.frame(of: list(width: 80, height: 40, items: [revealed]))

        // Then
        #expect(difference(cut, whole).largest < 0.03)
    }

    // MARK: - Private
    // Shapes with edges off the pixel grid in a 20 by 20 list: an ellipse, a thin diagonal stroke and a square.
    private func scene() -> DisplayList {
        let ellipse = PathItem(
            geometry: .ellipse(Rectangle(x: 2.3, y: 3.1, width: 12.4, height: 9.7)),
            fill: Color(written: "#FF0000"),
            stroke: nil
        )
        let stroke = PathStroke(width: 1.3, color: Color(written: "#0000FF"), join: .miter, cap: .butt, start: .none, end: .none)
        let line = PathItem(
            geometry: .polyline([Point(x: 1.7, y: 18.2), Point(x: 17.9, y: 1.4)], isClosed: false),
            fill: nil,
            stroke: stroke
        )
        let square = PathItem(filling: Rectangle(x: 13.2, y: 12.6, width: 5.1, height: 4.3), color: Color(written: "#00FF00"))

        return DisplayList(size: Size(width: 20, height: 20), background: Self.clear, seed: 0, items: [
            DisplayItem(content: .path(ellipse)),
            DisplayItem(content: .path(line)),
            DisplayItem(content: .path(square))
        ])
    }

    // A 40 by 40 list on white whose look depends on lengths in pixels: a shadow, a feathered mask, an adjustment's
    // blur over both, a picture with a blur filter and a border, and a square cut by a track matte.
    private func effects() -> DisplayList {
        let shadowed = PathItem(
            geometry: .rect(Rectangle(x: 6, y: 6, width: 14, height: 10), radius: 0),
            fill: Color(written: "#FF0000"),
            stroke: nil,
            shadow: DropShadow(radius: 2, offset: Point(x: 3, y: 2), color: Self.black)
        )
        let feathered = ItemMask(
            geometry: .rect(Rectangle(x: 22, y: 20, width: 10, height: 16), radius: 0),
            transform: .identity,
            feather: 2,
            isInverted: false,
            mode: .add
        )
        let ellipse = PathItem(
            geometry: .ellipse(Rectangle(x: 20, y: 18, width: 14, height: 14)),
            fill: Color(written: "#0000FF"),
            stroke: nil
        )
        let inner = DisplayList(size: Size(width: 10, height: 10), background: Self.clear, seed: 0, items: [
            DisplayItem(content: .path(PathItem(filling: Rectangle(x: 2, y: 2, width: 6, height: 6), color: Color(written: "#00FF00"))))
        ])
        let filtered = PictureItem(
            source: .displayList(inner),
            rectangle: nil,
            destination: Rectangle(x: 4, y: 24, width: 12, height: 12),
            filter: [.blur(radius: 1)],
            border: MediaBorder(width: 1, color: Self.black)
        )
        let matteSource = DisplayList(size: Size(width: 40, height: 40), background: Self.clear, seed: 0, items: [
            DisplayItem(content: .path(PathItem(
                geometry: .ellipse(Rectangle(x: 24, y: 4, width: 12, height: 12)),
                fill: Self.black,
                stroke: nil
            )))
        ])
        let matted = PathItem(filling: Rectangle(x: 24, y: 4, width: 12, height: 12), color: Color(written: "#FF00FF"))

        return DisplayList(size: Size(width: 40, height: 40), background: Self.white, seed: 0, items: [
            DisplayItem(content: .path(shadowed)),
            DisplayItem(mask: [feathered], content: .path(ellipse)),
            DisplayItem(content: .adjust(AdjustItem(filter: [.blur(radius: 1.5)]))),
            DisplayItem(content: .picture(filtered)),
            DisplayItem(
                trackMatte: ItemTrackMatte(source: matteSource, mode: .alpha, isInverted: false),
                content: .path(matted)
            )
        ])
    }

    // A 40 by 40 list, black left of x = 16 and white right of it, under an adjustment's blur of radius 2, which reads
    // 8 pixels past any point.
    private func blurredEdge() -> DisplayList {
        list(size: 40, items: [
            DisplayItem(content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 16, height: 40), color: Self.black))),
            DisplayItem(content: .path(PathItem(filling: Rectangle(x: 16, y: 0, width: 24, height: 40), color: Self.white))),
            DisplayItem(content: .adjust(AdjustItem(filter: [.blur(radius: 2)])))
        ])
    }

    private func picture(of list: DisplayList) -> PictureItem {
        PictureItem(
            source: .displayList(list),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: list.size.width, height: list.size.height)
        )
    }

    private func list(
        size: Double,
        items: [DisplayItem]
    ) -> DisplayList {
        list(width: size, height: size, items: items)
    }

    private func list(
        width: Double,
        height: Double,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: Size(width: width, height: height), background: Self.clear, seed: 0, items: items)
    }

    // The item with `transform` applied after its own.
    private func moved(
        _ item: DisplayItem,
        by transform: Frames.AffineTransform
    ) -> DisplayItem {
        let matrix = CGAffineTransform(item.transform).concatenating(CGAffineTransform(transform))

        return DisplayItem(
            transform: Frames.AffineTransform(a: matrix.a, b: matrix.b, c: matrix.c, d: matrix.d, tx: matrix.tx, ty: matrix.ty),
            content: item.content
        )
    }

    // The list drawn at its own size, then that image drawn through `transform` into a frame `size` across.
    private func scaledUp(
        _ list: DisplayList,
        by transform: Frames.AffineTransform,
        size: Int
    ) throws -> Bitmap {
        let image = try sut.frame(of: list).cgImage()
        let frame = try FrameContext(width: size, height: size)
        frame.context.concatenate(CGAffineTransform(transform))
        frame.context.drawUpright(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        return frame.bitmap()
    }

    // The largest and the mean difference of any component between two bitmaps over the first's size, which the
    // second holds.
    private func difference(
        _ left: Bitmap,
        _ right: Bitmap
    ) -> (largest: Double, mean: Double) {
        var largest = 0.0
        var total = 0.0
        for y in 0..<left.height {
            for x in 0..<left.width {
                for (first, second) in zip(left.pixel(x: x, y: y), right.pixel(x: x, y: y)) {
                    largest = max(largest, abs(first - second))
                    total += abs(first - second)
                }
            }
        }

        return (largest, total / Double(left.width * left.height * 4))
    }

    // Each two by two block of pixels averaged, rows from the top.
    private func halved(_ bitmap: Bitmap) -> [[Double]] {
        let width = bitmap.width / 2
        let height = bitmap.height / 2

        return (0..<(width * height)).map { index in
            let x = index % width * 2
            let y = index / width * 2
            let block = [
                bitmap.pixel(x: x, y: y),
                bitmap.pixel(x: x + 1, y: y),
                bitmap.pixel(x: x, y: y + 1),
                bitmap.pixel(x: x + 1, y: y + 1)
            ]

            return (0..<4).map { component in block.map { $0[component] }.reduce(0, +) / 4 }
        }
    }
}
