//
//  ShapeEvaluatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Testing

@testable import Frames

// Shapes are sequence clips in a 200 x 100 frame. A shape placed by `width` and `height` is 40 by 20 with its top left
// at (40, 20), as the rect given by `area` is.
@Suite("ShapeEvaluator Tests")
struct ShapeEvaluatorTests {
    // MARK: - Property
    private static let red = Color(written: "#FF0000")
    private static let frame = Rectangle(x: 0, y: 0, width: 200, height: 100)
    private static let area = Rectangle(x: 40, y: 20, width: 40, height: 20)
    private static let stroke = PathStroke(width: 4, paint: .color(red), join: .round, cap: .butt, start: .none, end: .none)
    private static let shadow = DropShadow(radius: 6, offset: Point(x: 2, y: 4), color: red)

    private let sut = ShapeEvaluator()

    private let space = ClipSpace(frame: Self.frame)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "after the transform a shape's lengths are its own times its own and its animation's scale, not its parent's",
        arguments: ["rect by area", "ellipse by area", "path", "rect by width and height", "ellipse by width and height"]
    )
    func scalesLengthsByOwnScaleOnly(placement: String) throws {
        // Given
        // The parent doubles its space, the clip is at scale 3 and its entrance at scale 2 throughout.
        let parent = ClipSpace(frame: Self.frame, transform: AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 10, ty: 0))
        let entrance = AnimationSpan(length: 2, span: Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.scale: 2]),
            SpanKey(t: 1, values: [.scale: 2])
        ]))
        let clip = clip(placedBy: placement, scale: Scale(3), entrance: entrance)
        let shape = try #require(resolvedShape(of: clip))

        // When
        let items = sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 1), in: parent, at: 1)

        // Then
        let item = try #require(items.first)
        guard case let .path(path) = item.content else {
            Issue.record("a shape draws one path item")
            return
        }
        // Widths are in output pixels; the radius and the shadow's offset are carried by the transform.
        let factor = item.transform.lengthFactor
        #expect(abs(try #require(path.stroke).width - 4 * 6) < 1e-9)
        if case let .rect(_, radius) = path.geometry {
            #expect(abs(radius * factor - 2 * 6) < 1e-9)
        }
        #expect(abs(try #require(path.shadow).radius - 6 * 6) < 1e-9)
        #expect(abs(try #require(path.shadow).offset.y * factor - 4 * 6) < 1e-9)
    }

    @Test(
        "a shape at scale [2, 1] draws its stroke at the geometric mean and its corners carried, 2r wide and r tall",
        arguments: ["rect by area", "rect by width and height"]
    )
    func carriesCornersUnderPerAxisScale(placement: String) throws {
        // Given
        let clip = clip(placedBy: placement, scale: Scale(x: 2, y: 1))
        let shape = try #require(resolvedShape(of: clip))

        // When
        let items = sut.items(
            of: shape,
            clip: clip,
            sample: ClipSample(clip: clip, at: 1),
            in: ClipSpace(frame: Self.frame),
            at: 1
        )

        // Then
        let item = try #require(items.first)
        guard case let .path(path) = item.content, case let .rect(_, radius) = path.geometry else {
            Issue.record("a rect draws one path item with a rect geometry")
            return
        }
        #expect(abs(try #require(path.stroke).width - 4 * 2.0.squareRoot()) < 1e-9)
        #expect(abs(radius * item.transform.a - 2 * 2) < 1e-9)
        #expect(abs(radius * item.transform.d - 2) < 1e-9)
    }

    @Test("a shape placed by its area turns about the centre of its geometry's box by default")
    func rotatesAreaShapeAboutCentre() throws {
        // Given
        let clip = clip(placedBy: "rect by area", rotation: 90)
        let shape = try #require(resolvedShape(of: clip))

        // When
        let item = try #require(sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)
            .first)

        // Then
        // The top left corner is 20 left of and 10 above the centre (60, 30), and turns clockwise to 10 right of it and
        // 20 above it.
        expect(item.transform.apply(to: Point(x: 60, y: 30)), Point(x: 60, y: 30))
        expect(item.transform.apply(to: Point(x: 40, y: 20)), Point(x: 70, y: 10))
    }

    @Test("a shape placed by its area turns about its named anchor, and its position moves that point there")
    func rotatesAreaShapeAboutAnchor() throws {
        // Given
        let shape = ResolvedShape(
            kind: .rect,
            geometry: .area(
                .keyframes([Keyframe(at: 0, value: .rectangle(Self.area))]),
                outset: 0,
                placement: GeometryPlacement(
                    position: [Keyframe(at: 0, value: Point(x: 150, y: 50))],
                    anchor: Point(x: 40, y: 20)
                )
            ),
            radius: 0,
            trim: [Keyframe(at: 0, value: .whole)],
            fill: .fill(Self.red),
            stroke: .off,
            shadow: .off
        )
        let clip = clip(shape, box: nil, rotation: 90)

        // When
        let item = try #require(sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)
            .first)

        // Then
        // The bottom right corner is 40 right of and 20 below the anchor, and turns to 20 left of it and 40 below it.
        expect(item.transform.apply(to: Point(x: 40, y: 20)), Point(x: 150, y: 50))
        expect(item.transform.apply(to: Point(x: 80, y: 40)), Point(x: 130, y: 90))
    }

    @Test("a box shape is drawn in its box's own pixels, its anchor point where its position puts it, turning about it")
    func rotatesBoxShapeAboutAnchor() throws {
        // Given
        // The anchor is the box's bottom right, at (80, 40).
        let box = ResolvedBox(
            size: Size(width: 40, height: 20),
            position: [Keyframe(at: 0, value: Point(x: 80, y: 40))],
            anchor: Point(x: 40, y: 20)
        )
        let shape = boxShape(kind: .rect, width: [Keyframe(at: 0, value: 40)])
        let clip = clip(shape, box: box, rotation: 90)

        // When
        let item = try #require(sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)
            .first)

        // Then
        #expect(item.content == .path(PathItem(
            geometry: .rect(Rectangle(x: 0, y: 0, width: 40, height: 20), radius: 2),
            fill: nil,
            stroke: Self.stroke
        )))
        expect(item.transform.apply(to: Point(x: 40, y: 20)), Point(x: 80, y: 40))
        expect(item.transform.apply(to: Point(x: 0, y: 0)), Point(x: 100, y: 0))
    }

    @Test("a box shape's keyframed width keeps its anchor point where it is, the anchor scaled with the box")
    func keepsAnchorPointWhileWidthChanges() throws {
        // Given
        // The anchor is the middle of the box's right side, at (80, 30), and the width goes from 40 to 80.
        let box = ResolvedBox(
            size: Size(width: 40, height: 20),
            position: [Keyframe(at: 0, value: Point(x: 80, y: 30))],
            anchor: Point(x: 40, y: 10)
        )
        let shape = boxShape(kind: .ellipse, width: [Keyframe(at: 0, value: 40), Keyframe(at: 2, value: 80)])
        let clip = clip(shape, box: box)

        // When
        let item = try #require(sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)
            .first)

        // Then
        guard case let .path(path) = item.content else {
            Issue.record("a shape draws one path item")
            return
        }
        #expect(path.geometry == .ellipse(Rectangle(x: 0, y: 0, width: 60, height: 20)))
        expect(item.transform.apply(to: Point(x: 60, y: 10)), Point(x: 80, y: 30))
        expect(item.transform.apply(to: Point(x: 0, y: 0)), Point(x: 20, y: 20))
    }

    @Test("a quarter of the way through a reveal from the right, a shape shows the quarter of its stroked outline")
    func revealsReceiverBox() throws {
        // Given
        let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .right, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ]))
        let clip = clip(placedBy: "rect by area", entrance: entrance)
        let shape = try #require(resolvedShape(of: clip))

        // When
        let item = try #require(sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 0.25), in: space, at: 0.25)
            .first)

        // Then
        // The stroke grows the area by 2, and the shadow's box, moved by (2, 4) and grown by 18, unites with it.
        let drawn = Rectangle(x: 38, y: 18, width: 44, height: 24)
        let cast = Rectangle(x: 22, y: 4, width: 80, height: 60)
        let receiver = drawn.union(cast)
        #expect(item.reveal == Rectangle(
            x: receiver.x + receiver.width * 0.75,
            y: receiver.y,
            width: receiver.width * 0.25,
            height: receiver.height
        ))
    }

    @Test(
        "a rect placed by its area keeps its outset in output pixels under a parent's zoom, its named anchor on its area as written",
        arguments: [0.5, 2.0]
    )
    func keepsOutsetUnderParentZoom(zoom: Double) throws {
        // Given
        // The outset is 4 output pixels, and the position puts the area's top left, as written, at (150, 50) in the
        // parent's space.
        let parent = ClipSpace(frame: Self.frame, transform: AffineTransform(a: zoom, b: 0, c: 0, d: zoom, tx: 10, ty: 0))
        let shape = ResolvedShape(
            kind: .rect,
            geometry: .area(
                .keyframes([Keyframe(at: 0, value: .rectangle(Self.area))]),
                outset: 4,
                placement: GeometryPlacement(
                    position: [Keyframe(at: 0, value: Point(x: 150, y: 50))],
                    anchor: Point(x: 40, y: 20)
                )
            ),
            radius: 0,
            trim: [Keyframe(at: 0, value: .whole)],
            fill: .fill(Self.red),
            stroke: .off,
            shadow: .off
        )
        let clip = clip(shape, box: nil)

        // When
        let item = try #require(sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 1), in: parent, at: 1)
            .first)

        // Then
        guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else {
            Issue.record("a rect draws one rect path item")
            return
        }
        let topLeft = item.transform.apply(to: Point(x: rectangle.x, y: rectangle.y))
        let bottomRight = item.transform.apply(to: Point(x: rectangle.maxX, y: rectangle.maxY))
        #expect(abs(bottomRight.x - topLeft.x - (40 * zoom + 8)) < 1e-9)
        #expect(abs(bottomRight.y - topLeft.y - (20 * zoom + 8)) < 1e-9)
        // The outset grows the box out from the anchor point, 4 output pixels up and left.
        let anchor = parent.transform.apply(to: Point(x: 150, y: 50))
        expect(topLeft, Point(x: anchor.x - 4, y: anchor.y - 4))
    }

    // The rect is 40 by 20 at (40, 20), so its outline is 120 long. A stroke 4 wide grows the box by half its width,
    // and an arrowhead 16 long and wide is added where it lies: at the bottom right corner, pointing down, half a trim
    // along, and 1 below the top right corner, with its base 16 above the tip and so above the box, at 41 / 120.
    @Test(
        "a closed rect's arrowhead adds its own box to the receiver box only where a trim leaves part of its outline undrawn",
        arguments: [
            (Trim.whole, Rectangle(x: 38, y: 18, width: 44, height: 24)),
            (Trim(start: 0, end: 0.5), Rectangle(x: 38, y: 18, width: 50, height: 24)),
            (Trim(start: 0, end: 41.0 / 120), Rectangle(x: 38, y: 5, width: 50, height: 37))
        ]
    )
    func growsReceiverBoxByDrawnArrowheads(
        trim: Trim,
        receiver: Rectangle
    ) throws {
        // Given
        let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .right, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ]))
        let shape = ResolvedShape(
            kind: .rect,
            geometry: .area(.keyframes([Keyframe(at: 0, value: .rectangle(Self.area))]), outset: 0, placement: GeometryPlacement()),
            radius: 0,
            trim: [Keyframe(at: 0, value: trim)],
            fill: .off,
            stroke: .stroke(PathStroke(width: 4, paint: .color(Self.red), join: .round, cap: .butt, start: .none, end: .arrow)),
            shadow: .off
        )
        let clip = clip(shape, box: nil, entrance: entrance)

        // When
        let item = try #require(sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 0.25), in: space, at: 0.25)
            .first)

        // Then
        let reveal = try #require(item.reveal)
        expect(Point(x: reveal.x, y: reveal.y), Point(x: receiver.x + receiver.width * 0.75, y: receiver.y))
        expect(Point(x: reveal.maxX, y: reveal.maxY), Point(x: receiver.maxX, y: receiver.maxY))
    }

    @Test(
        "dash lengths and the dash offset are carried with the outline, an odd list taken twice over, and the width is not",
        arguments: [
            (Scale(1), [3.0], [3.0, 3], 1.0),
            (Scale(x: 2, y: 0.5), [3.0, 1, 2], [3.0, 1, 2, 3, 1, 2], 1.0),
            (Scale(4), [3.0, 1], [3.0, 1], 4.0)
        ]
    )
    func carriesDash(
        scale: Scale,
        written: [Double],
        dash: [Double],
        factor: Double
    ) throws {
        // Given
        // The shape's transform is its own scale, whose length factor is its scale factor, so a carried length is
        // written as it is.
        let stroke = PathStroke(width: 2, paint: .color(Self.red), join: .round, cap: .butt, start: .none, end: .none, dash: written, dashOffset: 5)
        let shape = ResolvedShape(
            kind: .rect,
            geometry: .area(.keyframes([Keyframe(at: 0, value: .rectangle(Self.area))]), outset: 0, placement: GeometryPlacement()),
            radius: 0,
            trim: [Keyframe(at: 0, value: .whole)],
            fill: .off,
            stroke: .stroke(stroke),
            shadow: .off
        )
        let clip = clip(shape, box: nil, scale: scale)

        // When
        let item = try #require(sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1).first)

        // Then
        guard case let .path(path) = item.content, let drawn = path.stroke else {
            Issue.record("the shape is a stroked path")
            return
        }
        #expect(drawn.dash == dash)
        #expect(drawn.dashOffset == 5)
        #expect(abs(drawn.width - 2 * factor) < 1e-9)
    }

    @Test("a trim keyframed out of 0 to 1 is clamped to it")
    func clampsTrim() throws {
        // Given
        let shape = ResolvedShape(
            kind: .ellipse,
            geometry: .area(.keyframes([Keyframe(at: 0, value: .rectangle(Self.area))]), outset: 0, placement: GeometryPlacement()),
            radius: 0,
            trim: [Keyframe(at: 0, value: Trim(start: -1, end: 3))],
            fill: .off,
            stroke: .stroke(Self.stroke),
            shadow: .off
        )
        let clip = clip(shape, box: nil)

        // When
        let items = sut.items(of: shape, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)

        // Then
        #expect(items.first?.content == .path(PathItem(geometry: .ellipse(Self.area), fill: nil, stroke: Self.stroke)))
    }

    @Test(
        "a shape placed by its geometry under a parent at scale 0 draws nothing, and its children land where it flattens",
        arguments: ["rect by area", "path"]
    )
    func drawsNothingAtZeroScale(placement: String) throws {
        // Given
        let transform = AffineTransform(a: 0, b: 0, c: 0, d: 0, tx: 10, ty: 20)
        let space = ClipSpace(frame: Self.frame, transform: transform)
        let clip = clip(placedBy: placement)
        let shape = try #require(resolvedShape(of: clip))
        let sample = ClipSample(clip: clip, at: 1)

        // When
        let items = sut.items(of: shape, clip: clip, sample: sample, in: space, at: 1)
        let children = sut.transform(of: shape, clip: clip, sample: sample, in: space, at: 1)

        // Then
        #expect(items.isEmpty)
        #expect(children == transform)
    }

    // MARK: - Private
    private func expect(
        _ point: Point,
        _ expected: Point,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            abs(point.x - expected.x) < 1e-9 && abs(point.y - expected.y) < 1e-9,
            "\(point) is not \(expected)",
            sourceLocation: sourceLocation
        )
    }

    private func resolvedShape(of clip: ResolvedClip) -> ResolvedShape? {
        guard case let .shape(shape) = clip.content else { return nil }

        return shape
    }

    // A stroked shape with a shadow, corners of radius 2, by each placement.
    private func clip(
        placedBy placement: String,
        scale: Scale? = nil,
        rotation: Double? = nil,
        entrance: AnimationSpan? = nil
    ) -> ResolvedClip {
        let box = ResolvedBox(
            size: Size(width: 40, height: 20),
            position: [Keyframe(at: 0, value: Point(x: 60, y: 30))],
            anchor: Point(x: 20, y: 10)
        )
        let shape = switch placement {
        case "rect by width and height":
            boxShape(kind: .rect, width: [Keyframe(at: 0, value: 40)], shadow: Self.shadow)

        case "ellipse by width and height":
            boxShape(kind: .ellipse, width: [Keyframe(at: 0, value: 40)], shadow: Self.shadow)

        case "path":
            ResolvedShape(
                kind: .path,
                geometry: .points(
                    .keyframes([Keyframe(at: 0, value: [.point(Point(x: 40, y: 20)), .point(Point(x: 80, y: 40))])]),
                    isClosed: false,
                    placement: GeometryPlacement()
                ),
                radius: 0,
                trim: [Keyframe(at: 0, value: .whole)],
                fill: .off,
                stroke: .stroke(Self.stroke),
                shadow: .shadow(Self.shadow)
            )

        default:
            ResolvedShape(
                kind: placement == "ellipse by area" ? .ellipse : .rect,
                geometry: .area(.keyframes([Keyframe(at: 0, value: .rectangle(Self.area))]), outset: 0, placement: GeometryPlacement()),
                radius: 2,
                trim: [Keyframe(at: 0, value: .whole)],
                fill: .off,
                stroke: .stroke(Self.stroke),
                shadow: .shadow(Self.shadow)
            )
        }

        return clip(
            shape,
            box: placement.hasSuffix("width and height") ? box : nil,
            scale: scale,
            rotation: rotation,
            entrance: entrance
        )
    }

    private func boxShape(
        kind: ShapeKind,
        width: [Keyframe<Double>],
        shadow: DropShadow? = nil
    ) -> ResolvedShape {
        ResolvedShape(
            kind: kind,
            geometry: .box(width: width, height: [Keyframe(at: 0, value: 20)], outset: 0),
            radius: 2,
            trim: [Keyframe(at: 0, value: .whole)],
            fill: .off,
            stroke: .stroke(Self.stroke),
            shadow: .shadow(shadow)
        )
    }

    private func clip(
        _ shape: ResolvedShape,
        box: ResolvedBox?,
        scale: Scale? = nil,
        rotation: Double? = nil,
        entrance: AnimationSpan? = nil
    ) -> ResolvedClip {
        ResolvedClip(
            place: "clips[0]",
            id: nil,
            content: .shape(shape),
            start: 0,
            end: 4,
            lane: 1,
            storyline: nil,
            parent: nil,
            box: box,
            crop: nil,
            mask: nil,
            trackMatte: nil,
            track: nil,
            opacity: [Keyframe(at: 0, value: 1)],
            scale: scale.map { [Keyframe(at: 0, value: $0)] },
            rotation: rotation.map { [Keyframe(at: 0, value: $0)] },
            blend: "normal",
            animation: ResolvedAnimation(entrance: entrance, loop: nil, exit: nil, units: nil)
        )
    }
}
