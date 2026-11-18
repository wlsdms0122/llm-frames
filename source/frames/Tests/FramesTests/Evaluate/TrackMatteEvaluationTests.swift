//
//  TrackMatteEvaluationTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

@Suite("Track Matte Evaluation Tests")
struct TrackMatteEvaluationTests {
    // MARK: - Property
    private let sut = Evaluator()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a matte clip draws no item of its own, its child is drawn, and the clip it cuts takes its items as the source")
    func skipsMatteClip() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
              { "id": "m", "shape": "rect", "area": [0, 0, 540, 960], "fill": "#FFFFFF", "blend": "multiply", "at": [0, 4] },
              { "id": "kid", "shape": "rect", "area": [0, 0, 10, 10], "fill": "#FFFFFF", "parent": "m", "at": [0, 4] },
              { "id": "a", "title": "a", "style": "title", "at": [0, 4], "trackMatte": { "clip": "m", "mode": "alpha" } }
            ] }
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        #expect(list.items.compactMap { $0.origin?.id } == ["kid", "a"])
        let trackMatte = try #require(list.items.last?.trackMatte)
        #expect(trackMatte.source.size == list.size)
        #expect(trackMatte.source.background == Color(written: "#00000000"))
        #expect(trackMatte.source.items.compactMap { $0.origin?.id } == ["m"])
        #expect(trackMatte.source.items.map(\.blend) == ["normal"])
        #expect(trackMatte.mode == .alpha)
        #expect(!trackMatte.isInverted)
        #expect(list.items.first?.trackMatte == nil)
    }

    @Test("a matte clip's picture is what it would draw, its parent, animation and keyframes included, without its blend")
    func takesMatteAsDrawn() throws {
        // Given
        let clips = #"""
              { "id": "p", "shape": "rect", "area": [0, 0, 100, 100], "fill": "#FFFFFF", "rotation": 30, "position": [300, 400], "at": [0, 4] },
              { "id": "m", "title": "m", "style": "title", "parent": "p", "position": [20, 30], "blend": "screen", "animation": "frames/fade", "at": [0, 4],
                "keyframes": [ { "at": 0, "opacity": 0 }, { "at": 1, "opacity": 1 } ] }
            """#
        let matted = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ \#(clips),
              { "title": "a", "style": "title", "at": [0, 4], "trackMatte": { "clip": "m", "mode": "luma", "invert": true } }
            ] }
            """#)
        let drawn = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ \#(clips) ] }
            """#)

        // When
        let list = sut.displayList(of: matted, at: 0.1)
        let alone = sut.displayList(of: drawn, at: 0.1)

        // Then
        let trackMatte = try #require(list.items.last?.trackMatte)
        let expected = alone.items.filter { $0.origin?.id == "m" }
        #expect(!expected.isEmpty)
        #expect(expected.allSatisfy { $0.opacity > 0 && $0.opacity < 0.5 })
        #expect(trackMatte.source.items == expected.map { $0.normallyBlended() })
        #expect(trackMatte.mode == .luma)
        #expect(trackMatte.isInverted)
    }

    @Test("a matte used by two clips cuts both, and a matte with its own track matte carries it in its source")
    func followsSharedMatteAndChain() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
              { "id": "far", "shape": "ellipse", "area": [0, 0, 300, 300], "fill": "#FFFFFF", "at": [0, 4] },
              { "id": "near", "shape": "rect", "area": [0, 0, 540, 960], "fill": "#FFFFFF", "at": [0, 4], "trackMatte": { "clip": "far", "mode": "luma", "invert": true } },
              { "id": "a", "title": "a", "style": "title", "at": [0, 4], "trackMatte": { "clip": "near", "mode": "alpha" } },
              { "id": "b", "title": "b", "style": "title", "at": [0, 4], "trackMatte": { "clip": "near", "mode": "alpha" } }
            ] }
            """#)

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        #expect(list.items.compactMap { $0.origin?.id } == ["a", "b"])
        let first = try #require(list.items.first(where: { $0.origin?.id == "a" })?.trackMatte)
        #expect(list.items.first(where: { $0.origin?.id == "b" })?.trackMatte == first)
        let near = try #require(first.source.items.first)
        #expect(near.origin?.id == "near")
        let far = try #require(near.trackMatte)
        #expect(far.source.items.compactMap { $0.origin?.id } == ["far"])
        #expect(far.source.size == list.size)
        #expect(far.mode == .luma)
        #expect(far.isInverted)
    }

    @Test("outside its matte clip's visible window a track matte's source holds no item, so nothing of the clip shows")
    func emptiesMatteOutsideWindow() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
              { "id": "m", "shape": "rect", "area": [0, 0, 540, 960], "fill": "#FFFFFF", "at": [2, 3] },
              { "id": "a", "title": "a", "style": "title", "at": [0, 4], "trackMatte": { "clip": "m", "mode": "alpha" } }
            ] }
            """#)

        // When
        let before = sut.displayList(of: sequence, at: 1)
        let during = sut.displayList(of: sequence, at: 2.5)

        // Then
        #expect(before.items.compactMap { $0.origin?.id } == ["a"])
        #expect(before.items.last?.trackMatte?.source.items == [])
        #expect(during.items.last?.trackMatte?.source.items.compactMap { $0.origin?.id } == ["m"])
    }

    @Test("a storyline clip's track matte cuts its inner item, before the transition motion its outer item carries")
    func cutsStorylineInnerItem() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "storyline": [
              { "media": "/abs/run.mp4", "out": 2 },
              { "media": "/abs/run.mp4", "in": 2, "out": 4, "transition": "frames/push-up", "trackMatte": { "clip": "m", "mode": "alpha" } }
            ], "clips": [ { "id": "m", "shape": "rect", "area": [0, 0, 540, 960], "fill": "#FFFFFF", "at": [0, 4] } ] }
            """#)
        let incoming = 1

        // When
        let list = sut.displayList(of: sequence, at: 2)

        // Then
        let outer = try #require(list.items.first(where: { $0.origin?.place == "storyline[\(incoming)]" }))
        guard case let .picture(picture) = outer.content, case let .displayList(nested) = picture.source else {
            Issue.record("a storyline picture is a picture of a nested list")
            return
        }
        #expect(outer.trackMatte == nil)
        let trackMatte = try #require(nested.items.first?.trackMatte)
        #expect(trackMatte.source.size == nested.size)
        #expect(trackMatte.source.items.compactMap { $0.origin?.id } == ["m"])
        #expect(list.items.allSatisfy { $0.origin?.id != "m" })
    }

    // MARK: - Private
    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }
}
