//
//  ShapeEvaluatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// Shapes are sequence clips in a 200 x 100 frame, which is what a dim fills.
@Suite("ShapeEvaluator Tests")
struct ShapeEvaluatorTests {
    // MARK: - Property
    private static let red = Color(written: "#FF0000")
    private static let frame = Rectangle(x: 0, y: 0, width: 200, height: 100)
    private static let area = Rectangle(x: 40, y: 20, width: 40, height: 20)

    private let sut = ShapeEvaluator()

    private let space = ClipSpace(frame: Self.frame)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a quarter of the way through a reveal from the right, each shape kind's path shows a quarter as it reveals",
        arguments: [
            (
                ShapeDrawing.box(width: 4, radius: 2, color: ShapeEvaluatorTests.red),
                DisplayItem(content: .path(ShapeEvaluatorTests.stroked(
                    .rect(ShapeEvaluatorTests.area, radius: 2),
                    width: 4,
                    end: .none,
                    trim: 0.25
                )))
            ),
            (
                ShapeDrawing.fill(color: ShapeEvaluatorTests.red),
                DisplayItem(
                    reveal: Rectangle(x: 70, y: 20, width: 10, height: 20),
                    content: .path(PathItem(filling: ShapeEvaluatorTests.area, color: ShapeEvaluatorTests.red))
                )
            ),
            (
                ShapeDrawing.dim(color: ShapeEvaluatorTests.red),
                DisplayItem(content: .path(PathItem(filling: ShapeEvaluatorTests.frame, color: ShapeEvaluatorTests.red)))
            ),
            (
                ShapeDrawing.arrow(side: .left, length: 30, width: 2, head: 8, color: ShapeEvaluatorTests.red),
                DisplayItem(content: .path(ShapeEvaluatorTests.stroked(
                    .polyline([Point(x: 10, y: 30), Point(x: 40, y: 30)], isClosed: false),
                    width: 2,
                    end: .arrow,
                    trim: 0.25
                )))
            )
        ]
    )
    func revealsEachKind(
        drawing: ShapeDrawing,
        item: DisplayItem
    ) {
        // Given
        // A dim fills the whole frame, and the arrow runs from its tail 30 left of the area to its tip at the middle of
        // the area's left side.
        let entrance = AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .right, keys: [
            SpanKey(t: 0, values: [.reveal: 0]),
            SpanKey(t: 1, values: [.reveal: 1])
        ]))
        let clip = shape(drawing, area: [Keyframe(at: 0, value: Self.area)], entrance: entrance)

        // When
        let items = sut.items(of: drawing, clip: clip, sample: ClipSample(clip: clip, at: 0.25), in: space, at: 0.25)

        // Then
        #expect(items == [item])
    }

    @Test("a shape without an area is drawn on the frame, and a dim without one fills all of it")
    func drawsOnRoomWithoutArea() {
        // Given
        let drawing = ShapeDrawing.dim(color: Self.red)
        let clip = shape(drawing, area: nil)

        // When
        let items = sut.items(of: drawing, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)

        // Then
        #expect(items == [DisplayItem(content: .path(PathItem(filling: Self.frame, color: Self.red)))])
    }

    @Test(
        "a shape on an area under a parent is carried whole by P, its lengths divided by P's scale so they stay",
        arguments: [
            (
                ShapeDrawing.box(width: 4, radius: 2, color: ShapeEvaluatorTests.red),
                DisplayContent.path(ShapeEvaluatorTests.stroked(
                    .rect(ShapeEvaluatorTests.area, radius: 1),
                    width: 2,
                    end: .none,
                    trim: 1
                ))
            ),
            (
                ShapeDrawing.arrow(side: .left, length: 30, width: 2, head: 8, color: ShapeEvaluatorTests.red),
                DisplayContent.path(ShapeEvaluatorTests.stroked(
                    .polyline([Point(x: 25, y: 30), Point(x: 40, y: 30)], isClosed: false),
                    width: 1,
                    end: .arrow,
                    trim: 1
                ))
            )
        ]
    )
    func keepsLengthsUnderParent(
        drawing: ShapeDrawing,
        content: DisplayContent
    ) {
        // Given
        let transform = AffineTransform(a: 2, b: 0, c: 0, d: 2, tx: 10, ty: 0)
        let space = ClipSpace(frame: Self.frame, transform: transform)
        let clip = shape(drawing, area: [Keyframe(at: 0, value: Self.area)])

        // When
        let items = sut.items(of: drawing, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)

        // Then
        #expect(items == [DisplayItem(transform: transform, content: content)])
    }

    @Test(
        "a shape on an area under a parent at scale 0 draws nothing, and its children land on the point it flattens to",
        arguments: [
            ShapeDrawing.box(width: 4, radius: 2, color: ShapeEvaluatorTests.red),
            ShapeDrawing.arrow(side: .left, length: 30, width: 2, head: 8, color: ShapeEvaluatorTests.red)
        ]
    )
    func drawsNothingAtZeroScale(drawing: ShapeDrawing) {
        // Given
        let transform = AffineTransform(a: 0, b: 0, c: 0, d: 0, tx: 10, ty: 20)
        let space = ClipSpace(frame: Self.frame, transform: transform)
        let clip = shape(drawing, area: [Keyframe(at: 0, value: Self.area)])
        let sample = ClipSample(clip: clip, at: 1)

        // When
        let items = sut.items(of: drawing, clip: clip, sample: sample, in: space, at: 1)
        let children = sut.transform(of: drawing, clip: clip, sample: sample, in: space, at: 1)

        // Then
        #expect(items.isEmpty)
        #expect(children == transform)
    }

    // MARK: - Private
    // A red stroke with miter joins and butt caps, drawn from the start of its outline as far as `trim`.
    private static func stroked(
        _ geometry: PathGeometry,
        width: Double,
        end: StrokeEnd,
        trim: Double
    ) -> PathItem {
        PathItem(
            geometry: geometry,
            fill: nil,
            stroke: PathStroke(width: width, color: red, join: .miter, cap: .butt, start: .none, end: end),
            trim: Trim(start: 0, end: trim)
        )
    }

    private func shape(
        _ drawing: ShapeDrawing,
        area: [Keyframe<Rectangle>]?,
        entrance: AnimationSpan? = nil
    ) -> ResolvedClip {
        ResolvedClip(
            place: "clips[0]",
            id: nil,
            content: .shape(drawing),
            start: 0,
            end: 4,
            lane: 1,
            storyline: nil,
            parent: nil,
            area: area,
            box: nil,
            crop: nil,
            track: nil,
            opacity: [Keyframe(at: 0, value: 1)],
            scale: nil,
            rotation: nil,
            blend: "normal",
            animation: ResolvedAnimation(entrance: entrance, loop: nil, exit: nil)
        )
    }
}
