//
//  MotionBlurEvaluationTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

// Each document is resolved and evaluated at 25 fps under the default shutter, so the instants of the frame at T are
// T + 0.00125 × (i + 0.5) for i = 0 ... 15 (FRAMES-29).
@Suite("Motion Blur Evaluation Tests")
struct MotionBlurEvaluationTests {
    // MARK: - Property
    private let sut = Evaluator()
    private let offsets = (0 ..< 16).map { 0.00125 * (Double($0) + 0.5) }

    // MARK: - Initializer
    // MARK: - Test
    @Test("the instants are the midpoints of N equal parts of the exposure, which a phase of -angle ends at T")
    func placesInstants() {
        // Given
        let leading = Shutter.default
        let trailing = Shutter(angle: 360, phase: -360, samplesPerFrame: 4)

        // When
        let instants = leading.instants(at: 2, fps: 25)
        let before = trailing.instants(at: 2, fps: 25)

        // Then
        #expect(instants.count == 16)
        #expect(abs(instants[0] - 2.000625) < 1e-12)
        #expect(abs(instants[15] - 2.019375) < 1e-12)
        #expect(zip(before, [1.965, 1.975, 1.985, 1.995]).allSatisfy { abs($0 - $1) < 1e-12 })
    }

    @Test("a frame where no clip has motionBlur is one list, the list without motion blur")
    func keepsOneListWithoutSwitch() throws {
        // Given
        let sequence = try resolved(clips: [slider(isMotionBlurred: false)])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        #expect(list.samples == nil)
        #expect(list == sut.displayListWithoutMotionBlur(of: sequence, at: 1))
    }

    @Test("a clip with motionBlur that does not move gives N samples that are all the list as at T")
    func writesEqualSamples() throws {
        // Given
        let still = ##"{ "id": "still", "shape": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "position": [500, 500], "motionBlur": true }"##
        let sequence = try resolved(clips: [still])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let samples = try #require(list.samples)
        #expect(samples.count == 16)
        #expect(samples.allSatisfy { $0 == sut.displayListWithoutMotionBlur(of: sequence, at: 1).items })
        #expect(list.items.isEmpty)
    }

    @Test("a sliding clip with motionBlur stands at each instant in its sample, and the samples read back")
    func movesClipPerInstant() throws {
        // Given
        let sequence = try resolved(clips: [slider(isMotionBlurred: true)])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let at = try x(of: "slider", in: sut.displayListWithoutMotionBlur(of: sequence, at: 1).items)
        let shifts = try (list.samples ?? []).map { try x(of: "slider", in: $0) - at }
        #expect(isClose(shifts, offsets.map { $0 * 500 }))
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test("a step keyframe at 1.53 holds every instant of the frame at 1.52 at the old place")
    func clampsStepKeyframe() throws {
        // Given
        let stepped = #"""
            { "id": "stepped", "shape": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "motionBlur": true,
              "keyframes": [ { "at": 1, "position": [100, 500], "ease": "step" }, { "at": 1.53, "position": [900, 500] } ] }
            """#
        let sequence = try resolved(clips: [stepped])

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1.52).samples)
        let next = try #require(sut.displayList(of: sequence, at: 1.56).samples)

        // Then
        let before = try x(of: "stepped", in: sut.displayListWithoutMotionBlur(of: sequence, at: 1.52).items)
        let after = try x(of: "stepped", in: sut.displayListWithoutMotionBlur(of: sequence, at: 1.56).items)
        #expect(try samples.allSatisfy { try x(of: "stepped", in: $0) == before })
        #expect(try next.allSatisfy { try x(of: "stepped", in: $0) == after })
        #expect(after - before == 800)
    }

    @Test("a child without motionBlur rides a parent with it, so it moves with the parent in every sample")
    func ridesBlurredParent() throws {
        // Given
        let sequence = try resolved(clips: [slider(isMotionBlurred: true), child(isMotionBlurred: false, growing: false)])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let at = try x(of: "child", in: sut.displayListWithoutMotionBlur(of: sequence, at: 1).items)
        let shifts = try (list.samples ?? []).map { try x(of: "child", in: $0) - at }
        #expect(isClose(shifts, offsets.map { $0 * 500 }))
    }

    @Test("a child with motionBlur under a parent without it is blurred by its own growth alone")
    func blursOwnGrowthOnly() throws {
        // Given
        let sequence = try resolved(clips: [slider(isMotionBlurred: false), child(isMotionBlurred: true, growing: true)])

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1).samples)

        // Then
        let at = try bounds(of: "child", in: sut.displayListWithoutMotionBlur(of: sequence, at: 1).items)
        let drawn = try samples.map { try bounds(of: "child", in: $0) }
        #expect(drawn.allSatisfy { abs(($0.x + $0.width / 2) - (at.x + at.width / 2)) < 1e-6 })
        #expect(isClose(drawn.map { $0.width - at.width }, offsets.map { $0 * 100 }))
    }

    @Test("a bar placed by the area of a clip with motionBlur moves with it in every sample, whatever its own switch")
    func followsBlurredArea() throws {
        // Given
        let bar = ##"{ "id": "bar", "shape": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "slider", "padding": 10 } }"##
        let sequence = try resolved(clips: [slider(isMotionBlurred: true), bar])

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1).samples)

        // Then
        let at = try bounds(of: "bar", in: sut.displayListWithoutMotionBlur(of: sequence, at: 1).items)
        let shifts = try samples.map { try bounds(of: "bar", in: $0).x - at.x }
        #expect(isClose(shifts, offsets.map { $0 * 500 }))
    }

    @Test("a push brought in by a clip with motionBlur moves both sides by one progress, so they meet in every sample")
    func movesBothSidesOfPush() throws {
        // Given
        let sequence = pushSequence(isIncomingBlurred: true)

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1.8).samples)

        // Then
        let incoming = samples.map { $0[1].transform.apply(to: Point(x: 0, y: 0)).x }
        let outgoing = samples.map { $0[0].transform.apply(to: Point(x: 0, y: 0)).x }
        #expect(isClose(zip(incoming, outgoing).map { $0 - $1 }, Array(repeating: 200, count: 16)))
        #expect(isClose(incoming, offsets.map { 200 * (1 - (1.8 + $0 - 1.5)) }))
    }

    @Test("the outgoing clip's motionBlur does not move a transition the incoming clip brings in")
    func holdsPushOfSharpIncoming() throws {
        // Given
        let sequence = pushSequence(isIncomingBlurred: false)

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1.8).samples)

        // Then
        let at = sut.displayListWithoutMotionBlur(of: sequence, at: 1.8).items
        #expect(samples.allSatisfy { $0 == at })
    }

    @Test(
        "a clip X inside a compound clip C, each sliding against the other, blurs by the switches it and C have",
        arguments: [(true, true, 1.0, -1.0), (true, false, 1.0, 0.0), (false, true, 0.0, -1.0)]
    )
    func carriesInstantIntoCompound(isCompoundBlurred: Bool, isInnerBlurred: Bool, compound: Double, inner: Double) throws {
        // Given
        let sequence = try resolved(clips: [compoundClip(isMotionBlurred: isCompoundBlurred, inner: isInnerBlurred)])

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1).samples)

        // Then
        let at = sut.displayListWithoutMotionBlur(of: sequence, at: 1).items
        let compoundShifts = try samples.map { try x(of: "c", in: $0) - x(of: "c", in: at) }
        let innerShifts = try samples.map { try x(of: "x", in: nested(in: $0)) - x(of: "x", in: nested(in: at)) }
        let staticShifts = try samples.map { try x(of: "y", in: nested(in: $0)) - x(of: "y", in: nested(in: at)) }
        #expect(isClose(compoundShifts, offsets.map { $0 * 500 * compound }))
        #expect(isClose(innerShifts, offsets.map { $0 * 500 * inner }))
        #expect(isClose(staticShifts, Array(repeating: 0, count: 16)))
    }

    @Test("where timeRemap holds a frame over the exposure every nested time is m(T), so the clips inside stand still")
    func holdsRemappedCompound() throws {
        // Given
        let remap = #""keyframes": [ { "at": 0, "timeRemap": 1 }, { "at": 4, "timeRemap": 1 } ]"#
        let sequence = try resolved(clips: [compoundClip(isMotionBlurred: false, inner: true, extra: remap)])

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1).samples)

        // Then
        let at = sut.displayListWithoutMotionBlur(of: sequence, at: 1).items
        #expect(try samples.allSatisfy { try x(of: "x", in: nested(in: $0)) == x(of: "x", in: nested(in: at)) })
    }

    @Test("an edit point on a frame boundary is the frame's membership: the incoming clip draws in every sample at 2, the outgoing one at 1.96")
    func keepsCutAtEditPoint() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "id": "a", "solid": "#202020", "duration": 2, "motionBlur": true },
                             { "id": "b", "solid": "#404040", "duration": 2, "motionBlur": true } ] }
            """#)

        // When
        let incoming = try #require(sut.displayList(of: sequence, at: 2).samples)
        let outgoing = try #require(sut.displayList(of: sequence, at: 1.96).samples)

        // Then
        #expect(incoming.allSatisfy { $0.map(\.origin?.id) == ["b"] })
        #expect(outgoing.allSatisfy { $0.map(\.origin?.id) == ["a"] })
    }

    @Test("footage with motionBlur shows the media frame of T in every sample")
    func showsOneMediaFrame() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "media": "/abs/short.mp4", "in": 0, "out": 4, "motionBlur": true,
                               "keyframes": [ { "at": 0, "scale": 1 }, { "at": 4, "scale": 2 } ] } ] }
            """#)

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1.03).samples)

        // Then
        let frames = samples.map { mediaFrame(in: $0) }
        #expect(frames[0] != nil)
        #expect(frames.allSatisfy { $0 == frames[0] })
        #expect(frames[0] == mediaFrame(in: sut.displayListWithoutMotionBlur(of: sequence, at: 1.03).items))
        #expect(samples[0] != samples[15])
    }

    @Test("a clip with motionBlur whose crop tracks its media is carried by the motion of the media frame of T in every sample")
    func carriesTrackedCropAtT() throws {
        // Given
        // The exposure of the frame at 0.99 crosses from the media frame at 0.9 to the one at 1, whose motions differ by
        // 10 pixels.
        let sequence = try drifting(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "media": "/abs/screen.mp4", "in": 0, "out": 2, "crop": { "text": "Total" }, "track": true, "motionBlur": true } ] }
            """#)

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 0.99).samples)

        // Then
        let atT = sut.displayListWithoutMotionBlur(of: sequence, at: 0.99).items
        let next = sut.displayListWithoutMotionBlur(of: sequence, at: 1).items
        #expect(samples.allSatisfy { $0 == atT })
        #expect(crop(in: atT) != nil)
        #expect(crop(in: atT) != crop(in: next))
    }

    @Test("a box with motionBlur that tracks its parent's media stays on its target in every sample, as it does without motion blur")
    func keepsTrackedBoxOnTarget() throws {
        // Given
        // The exposure of the frame at 0.99 crosses from the media frame at 0.9 to the one at 1, on which the target has
        // drifted 10 pixels further.
        let document = { (isMotionBlurred: Bool) in
            #"""
                { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
                  "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 0, "out": 2, "connected": [
                    { "id": "box", "shape": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [0, 2], "area": { "text": "Total" },
                      "track": true, "motionBlur": \#(isMotionBlurred) } ] } ] }
                """#
        }
        let blurred = try drifting(document(true))
        let sharp = try drifting(document(false))

        // When
        let samples = try #require(sut.displayList(of: blurred, at: 0.99).samples)

        // Then
        let target = try bounds(of: "box", in: sut.displayList(of: sharp, at: 0.99).items)
        let next = try bounds(of: "box", in: sut.displayList(of: sharp, at: 1).items)
        let drawn = try samples.map { try bounds(of: "box", in: $0) }
        #expect(drawn.allSatisfy { isClose([$0.x, $0.y, $0.width, $0.height], [target.x, target.y, target.width, target.height]) })
        #expect(abs(next.x - target.x) > 1)
    }

    @Test("evaluate reports the frame as at T, the list without motion blur")
    func reportsFrameAtT() throws {
        // Given
        let blurred = try resolved(clips: [slider(isMotionBlurred: true)])
        let sharp = try resolved(clips: [slider(isMotionBlurred: false)])

        // When
        let report = try EvaluationReporter().report(of: blurred, at: 1)

        // Then
        #expect(report == (try EvaluationReporter().report(of: sharp, at: 1)))
    }

    // MARK: - Private
    // Slides right at 500 pixels a second, from 100 at 0 to 1100 at 2.
    private func slider(isMotionBlurred: Bool) -> String {
        #"""
            { "id": "slider", "shape": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "motionBlur": \#(isMotionBlurred),
              "keyframes": [ { "at": 0, "position": [100, 500] }, { "at": 2, "position": [1100, 500] } ] }
            """#
    }

    // Parented to the slider, and growing 100 pixels a second in width from 50 at 0 when `growing`.
    private func child(
        isMotionBlurred: Bool,
        growing: Bool
    ) -> String {
        let size = growing
            ? #""height": 20, "keyframes": [ { "at": 0, "width": 50 }, { "at": 2, "width": 250 } ]"#
            : #""width": 50, "height": 20"#
        return #"""
            { "id": "child", "shape": "rect", "fill": "#00FF00", "at": [0, 4], "parent": "slider", "position": [0, 0],
              "motionBlur": \#(isMotionBlurred), \#(size) }
            """#
    }

    // C slides right at 500 pixels a second and X inside it left at 500, while Y inside it stands still.
    private func compoundClip(
        isMotionBlurred: Bool,
        inner: Bool,
        extra: String? = nil
    ) -> String {
        let keyframes = extra ?? #""keyframes": [ { "at": 0, "position": [460, 540] }, { "at": 2, "position": [1460, 540] } ]"#
        return #"""
            { "id": "c", "at": [0, 4], "motionBlur": \#(isMotionBlurred), \#(keyframes),
              "media": { "kind": "sequence", "format": { "size": [1920, 1080] },
                         "storyline": [ { "solid": "#000000", "duration": 4 } ],
                         "clips": [ { "id": "x", "shape": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50,
                                      "motionBlur": \#(inner),
                                      "keyframes": [ { "at": 0, "position": [1500, 500] }, { "at": 2, "position": [500, 500] } ] },
                                    { "id": "y", "shape": "rect", "fill": "#00FF00", "at": [0, 4], "width": 100, "height": 50,
                                      "position": [300, 300] } ] } }
            """#
    }

    private func resolved(clips: [String]) throws -> ResolvedSequence {
        try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "id": "back", "solid": "#202020", "duration": 4 } ], "clips": [ \#(clips.joined(separator: ", ")) ] }
            """#)
    }

    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    // Resolved with a tracker whose target drifts 100 pixels a second over `/abs/screen.mp4`, which shows a new frame
    // every 0.1 seconds.
    private func drifting(_ document: String) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Fixture.presets,
            ocr: Fixture.ocr,
            languages: nil,
            tracker: TrackerTable(frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes], drift: Point(x: 100, y: 0)),
            shaper: Fixture.shaper,
            library: Fixture.library
        )

        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    // Two solids with a push from 1.5 to 2.5: the incoming one from x 1 to 0 of the frame, the outgoing from 0 to -1.
    private func pushSequence(isIncomingBlurred: Bool) -> ResolvedSequence {
        let size = Size(width: 200, height: 100)
        let frame = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let push = ResolvedTransition(
            start: 1.5,
            end: 2.5,
            over: .incoming,
            incoming: Span(ease: .linear, keys: [SpanKey(t: 0, values: [.x: 1]), SpanKey(t: 1, values: [.x: 0])]),
            outgoing: Span(ease: .linear, keys: [SpanKey(t: 0, values: [.x: 0]), SpanKey(t: 1, values: [.x: -1])]),
            cover: nil,
            matte: nil
        )
        let entry = { (place: String, start: Double, end: Double, isMotionBlurred: Bool, transition: ResolvedTransition?) in
            ResolvedStorylineClip(
                place: place,
                id: nil,
                media: nil,
                solid: Color(written: "#000000"),
                in: 0,
                out: end - start,
                speed: 1,
                start: start,
                end: end,
                crop: [Keyframe(at: start, value: Crop(frame))],
                track: nil,
                filter: .off,
                isMotionBlurred: isMotionBlurred,
                transition: transition,
                filling: size
            )
        }

        return ResolvedSequence(
            format: ResolvedFormat(size: size, fps: 25, duration: 4, background: .black, conform: .fit),
            storyline: [
                entry("storyline[0]", 0, 2, !isIncomingBlurred, nil),
                entry("storyline[1]", 2, 4, isIncomingBlurred, push)
            ],
            clips: [],
            audio: []
        )
    }

    private func item(
        _ id: String,
        in items: [DisplayItem]
    ) throws -> DisplayItem {
        try #require(items.last { $0.origin?.id == id })
    }

    private func x(
        of id: String,
        in items: [DisplayItem]
    ) throws -> Double {
        try item(id, in: items).transform.apply(to: Point(x: 0, y: 0)).x
    }

    // The rect a clip draws, bounded, in the pixels of its list.
    private func bounds(
        of id: String,
        in items: [DisplayItem]
    ) throws -> Rectangle {
        let item = try item(id, in: items)
        guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else {
            Issue.record("the clip draws no rect")
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }

        return Rectangle(bounding: item.transform.apply(toCornersOf: rectangle))
    }

    // The items of the compound clip C's nested list.
    private func nested(in items: [DisplayItem]) throws -> [DisplayItem] {
        guard case let .picture(picture) = try item("c", in: items).content, case let .displayList(list) = picture.source else {
            Issue.record("the compound clip draws no nested list")
            return []
        }

        return list.items
    }

    // The crop of the media the storyline picture shows.
    private func crop(in items: [DisplayItem]) -> Rectangle? {
        guard case let .picture(outer) = items.first?.content,
              case let .displayList(list) = outer.source,
              case let .picture(inner) = list.items.first?.content else { return nil }

        return inner.rectangle
    }

    // The media frame the storyline picture shows.
    private func mediaFrame(in items: [DisplayItem]) -> MediaFrame? {
        guard case let .picture(outer) = items.first?.content,
              case let .displayList(list) = outer.source,
              case let .picture(inner) = list.items.first?.content,
              case let .media(frame) = inner.source else { return nil }

        return frame
    }

    private func isClose(
        _ values: [Double],
        _ expected: [Double]
    ) -> Bool {
        values.count == expected.count && zip(values, expected).allSatisfy { abs($0 - $1) < 1e-6 }
    }
}
