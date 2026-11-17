//
//  ShapeEvaluatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// Shapes are sequence clips in a 200 x 100 frame, which is what a dim darkens.
@Suite("ShapeEvaluator Tests")
struct ShapeEvaluatorTests {
    // MARK: - Property
    private static let red = Color(written: "#FF0000")
    private static let frame = Rectangle(x: 0, y: 0, width: 200, height: 100)
    private static let area = Rectangle(x: 40, y: 20, width: 40, height: 20)

    private let sut = ShapeEvaluator()

    private let space = ClipSpace.output(frame: Self.frame)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a quarter of the way through a reveal from the right, each shape kind shows a quarter as its kind reveals",
        arguments: [
            (
                ShapeDrawing.box(width: 4, radius: 2, color: ShapeEvaluatorTests.red),
                DisplayItem(content: .stroke(StrokeItem(
                    rectangle: ShapeEvaluatorTests.area,
                    radius: 2,
                    width: 4,
                    color: ShapeEvaluatorTests.red,
                    trim: 0.25
                )))
            ),
            (
                ShapeDrawing.fill(color: ShapeEvaluatorTests.red),
                DisplayItem(
                    reveal: Rectangle(x: 70, y: 20, width: 10, height: 20),
                    content: .fill(FillItem(rectangle: ShapeEvaluatorTests.area, color: ShapeEvaluatorTests.red))
                )
            ),
            (
                ShapeDrawing.dim(color: ShapeEvaluatorTests.red),
                DisplayItem(content: .fill(FillItem(
                    rectangle: ShapeEvaluatorTests.frame,
                    color: ShapeEvaluatorTests.red,
                    hole: RoundedRectangle(rectangle: Rectangle(x: 10, y: 5, width: 160, height: 80), radius: 0)
                )))
            ),
            (
                ShapeDrawing.arrow(side: .left, length: 30, width: 2, head: 8, color: ShapeEvaluatorTests.red),
                DisplayItem(content: .arrow(ArrowItem(
                    tail: Point(x: 10, y: 30),
                    head: Point(x: 17.5, y: 30),
                    width: 2,
                    headSize: 8,
                    color: ShapeEvaluatorTests.red
                )))
            )
        ]
    )
    func revealsEachKind(
        drawing: ShapeDrawing,
        item: DisplayItem
    ) {
        // Given
        // The dim's hole closes a quarter of the way from the frame to the area, and the arrow, its tip at the middle
        // of the area's left side and its tail 30 beyond it, grows a quarter of its length from its tail.
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

    @Test("an arrow's nudge moves it towards what it points at by multiples of its length")
    func nudgesArrow() {
        // Given
        let drawing = ShapeDrawing.arrow(side: .left, length: 30, width: 2, head: 8, color: Self.red)
        let loop = AnimationSpan(length: 1, span: Span(ease: .linear, keys: [SpanKey(t: 0, values: [.nudge: 0.5])]))
        let clip = shape(drawing, area: [Keyframe(at: 0, value: Self.area)], loop: loop)

        // When
        let items = sut.items(of: drawing, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)

        // Then
        #expect(items == [DisplayItem(content: .arrow(ArrowItem(
            tail: Point(x: 25, y: 30),
            head: Point(x: 55, y: 30),
            width: 2,
            headSize: 8,
            color: Self.red
        )))])
    }

    @Test("a shape without an area is drawn on the frame, and a dim without one darkens all of it")
    func drawsOnRoomWithoutArea() {
        // Given
        let drawing = ShapeDrawing.dim(color: Self.red)
        let clip = shape(drawing, area: nil)

        // When
        let items = sut.items(of: drawing, clip: clip, sample: ClipSample(clip: clip, at: 1), in: space, at: 1)

        // Then
        #expect(items == [DisplayItem(content: .fill(FillItem(rectangle: Self.frame, color: Self.red)))])
    }

    // MARK: - Private
    private func shape(
        _ drawing: ShapeDrawing,
        area: [Keyframe<Rectangle>]?,
        entrance: AnimationSpan? = nil,
        loop: AnimationSpan? = nil
    ) -> ResolvedClip {
        ResolvedClip(
            place: "clips[0]",
            id: nil,
            content: .shape(drawing),
            start: 0,
            end: 4,
            lane: 1,
            storyline: nil,
            isParented: false,
            area: area,
            box: nil,
            crop: nil,
            track: nil,
            opacity: [Keyframe(at: 0, value: 1)],
            scale: nil,
            rotation: nil,
            blend: "normal",
            animation: ResolvedAnimation(entrance: entrance, loop: loop, exit: nil)
        )
    }
}
