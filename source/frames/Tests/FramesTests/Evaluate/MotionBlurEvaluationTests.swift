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
    // The track data of a tracker whose target [100, 100, 200, 40] drifts 100 pixels a second over `/abs/screen.mp4`,
    // which shows a new frame every 0.1 seconds, followed from media second 0.
    private var driftingTrack: String {
        TrackerTable(frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes], drift: Point(x: 100, y: 0))
            .data(Quad(Rectangle(x: 100, y: 100, width: 200, height: 40)), in: "/abs/screen.mp4", atMediaTime: 0, over: 0...2)
    }
    // A loop that slides its clip half its box to the right each second with its wipe complete throughout.
    private let drift = AnimationPreset(
        description: "",
        entrance: nil,
        loop: AnimationSpan(length: 1, span: Span(ease: .linear, revealFrom: .left, keys: [
            SpanKey(t: 0, values: [.x: 0, .reveal: 1]),
            SpanKey(t: 1, values: [.x: 0.5, .reveal: 1])
        ])),
        exit: nil
    )
    // Each field whose value can reach an end, keyframed or animated so that it does inside the exposure of the frame at
    // the time given: a picture's border width, which a clip takes from its theme and writes in output pixels at its
    // scale factor, so it reaches 0 only by a picture popping in from scale 0; a stroke's width from 0; a dash whose
    // `back-out` overshoot clamps every length to 0 from a progress of about 0.43; a stroked, dashed and shadowed shape
    // popping in from scale 0; and a reveal reaching 1, by a shape's wipe from 1 to 1.5, complete after T and before
    // it, by a picture's, and by a wipe transition from 1.5 to 2.5 inside a compound clip.
    private static let valuesThroughEnds: [(String, String?, Double)] = [
        (
            #"""
            { "id": "leaf", "kind": "media", "media": "/abs/card.png", "at": [1, 4], "border": true, "motionBlur": true,
              "keyframes": [ { "at": 1, "scale": 0 }, { "at": 1.5, "scale": 1 } ] }
            """#,
            #"{ "shutterPhase": -180 }"#,
            1.01
        ),
        (
            #"""
            { "id": "leaf", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "position": [500, 500],
              "stroke": { "paint": "#FFFFFF" }, "motionBlur": true,
              "keyframes": [ { "at": 0, "stroke": { "width": 0 } }, { "at": 1, "stroke": { "width": 0 } }, { "at": 2, "stroke": { "width": 10 } } ] }
            """#,
            nil,
            0.99
        ),
        (
            #"""
            { "id": "leaf", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "position": [500, 500],
              "stroke": { "width": 2, "paint": "#FFFFFF" }, "motionBlur": true,
              "keyframes": [ { "at": 0, "stroke": { "dash": [10, 10] }, "ease": "back-out" }, { "at": 1, "stroke": { "dash": [0.5, 0.5] } } ] }
            """#,
            nil,
            0.42
        ),
        (
            #"""
            { "id": "leaf", "kind": "rect", "fill": "#FF0000", "at": [1, 4], "width": 100, "height": 50, "position": [500, 500],
              "stroke": { "width": 2, "paint": "#FFFFFF", "dash": [4, 2] }, "shadow": { "radius": 4, "offset": [2, 2], "color": "#000000" },
              "motionBlur": true, "keyframes": [ { "at": 1, "scale": 0 }, { "at": 1.5, "scale": 1 } ] }
            """#,
            #"{ "shutterPhase": -180 }"#,
            1.01
        ),
        (
            #"""
            { "id": "leaf", "kind": "rect", "fill": "#FF0000", "at": [1, 4], "width": 100, "height": 50, "position": [500, 500],
              "animation": "mine/wipe-in", "motionBlur": true }
            """#,
            nil,
            1.49
        ),
        (
            #"""
            { "id": "leaf", "kind": "rect", "fill": "#FF0000", "at": [1, 4], "width": 100, "height": 50, "position": [500, 500],
              "animation": "mine/wipe-in", "motionBlur": true }
            """#,
            #"{ "shutterPhase": -180 }"#,
            1.51
        ),
        (
            #"{ "id": "leaf", "kind": "media", "media": "/abs/card.png", "at": [1, 4], "animation": "mine/wipe-in", "motionBlur": true }"#,
            nil,
            1.49
        ),
        (
            #"""
            { "id": "leaf", "at": [0, 4],
              "kind": "media",
              "media": { "kind": "sequence", "format": { "size": [1920, 1080] },
                         "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 },
                                        { "kind": "solid", "color": "#FFFFFF", "duration": 2, "transition": "mine/wipe-in", "motionBlur": true } ] } }
            """#,
            nil,
            2.49
        )
    ]

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
        let still = ##"{ "id": "still", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "position": [500, 500], "motionBlur": true }"##
        let sequence = try resolved(clips: [still])

        // When
        let list = sut.displayList(of: sequence, at: 1)

        // Then
        let samples = try #require(list.samples)
        #expect(samples.count == 16)
        #expect(samples.allSatisfy { $0 == sut.displayListWithoutMotionBlur(of: sequence, at: 1).items })
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

    @Test("a shape popping in from scale 0 gives its item in every sample, drawing nothing where it is flat, and the samples read back")
    func keepsPoppingShapeInEverySample() throws {
        // Given
        let popping = #"""
            { "id": "pop", "kind": "rect", "fill": "#FF0000", "at": [1, 4], "width": 100, "height": 50, "position": [500, 500],
              "motionBlur": true, "keyframes": [ { "at": 1, "scale": 0 }, { "at": 1.5, "scale": 1 } ] }
            """#
        let sequence = try resolved(clips: [popping], shutter: #"{ "shutterPhase": -180 }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1.01)

        // Then
        let samples = try #require(list.samples)
        let popped = try samples.map { try item("pop", in: $0) }
        #expect(samples.allSatisfy { $0.count { $0.origin?.id == "pop" } == 1 })
        #expect(popped.first?.transform.lengthFactor == 0)
        #expect((popped.last?.transform.lengthFactor ?? 0) > 0)
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test("a shape placed by area under a parent that passes through scale 0 gives its item in every sample, and the samples read back")
    func keepsChildOfFlatParentInEverySample() throws {
        // Given
        let parent = #"""
            { "id": "slider", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "position": [500, 500],
              "motionBlur": true,
              "keyframes": [ { "at": 0.9, "scale": 1 }, { "at": 1, "scale": 0 }, { "at": 1.005, "scale": 0 }, { "at": 1.1, "scale": 1 } ] }
            """#
        let child = #"""
            { "id": "child", "kind": "rect", "fill": "#00FF00", "at": [0, 4], "parent": "slider", "area": [0, 0, 20, 10] }
            """#
        let sequence = try resolved(clips: [parent, child])

        // When
        let list = sut.displayList(of: sequence, at: 0.99)

        // Then
        let samples = try #require(list.samples)
        let children = try samples.map { try item("child", in: $0) }
        #expect(samples.allSatisfy { $0.count { $0.origin?.id == "child" } == 1 && $0.count { $0.origin?.id == "slider" } == 1 })
        #expect(children.contains { $0.transform.lengthFactor == 0 })
        #expect(children.contains { $0.transform.lengthFactor > 0 })
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test("a stroke growing from width 0 is written in every sample with its width, 0 included, and kept out of the list at T")
    func keepsGrowingStrokeInEverySample() throws {
        // Given
        let stroked = #"""
            { "id": "stroked", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "position": [500, 500],
              "stroke": { "paint": "#FFFFFF" }, "motionBlur": true,
              "keyframes": [ { "at": 0, "stroke": { "width": 0 } }, { "at": 1, "stroke": { "width": 0 } }, { "at": 2, "stroke": { "width": 10 } } ] }
            """#
        let sequence = try resolved(clips: [stroked])

        // When
        let list = sut.displayList(of: sequence, at: 0.99)

        // Then
        let samples = try #require(list.samples)
        let widths = try samples.map { sample -> Double? in
            guard case let .path(path) = try item("stroked", in: sample).content else { return nil }

            return path.stroke?.width
        }
        let atT = try item("stroked", in: sut.displayListWithoutMotionBlur(of: sequence, at: 0.99).items)
        guard case let .path(path) = atT.content else { Issue.record("not a path"); return }

        #expect(widths.allSatisfy { $0 != nil })
        #expect(widths.first == 0)
        #expect((widths.last.flatMap { $0 } ?? 0) > 0)
        #expect(path.stroke == nil)
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test(
        "a field whose value reaches an end over an exposure is written with the same keys in every sample, and the samples read back",
        arguments: valuesThroughEnds
    )
    func keepsKeysOfValueThroughEnd(
        clip: String,
        shutter: String?,
        time: Double
    ) throws {
        // Given
        let sequence = try resolved(clips: [clip], shutter: shutter)

        // When
        let list = sut.displayList(of: sequence, at: time)

        // Then
        let written = try #require(try JSONReader().read(DisplayListWriter().write(list)).objectValue)
        let samples = try #require(written["samples"]?.arrayValue)
        let firstKeys = keys(of: samples[0])
        #expect(samples.count == 16)
        #expect(samples.allSatisfy { keys(of: $0) == firstKeys })
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test("a wipe that ends inside the exposure is written in every sample, whole once complete, and an item no reveal is set on in none")
    func keepsRevealInEverySample() throws {
        // Given
        let wiped = #"""
            { "id": "wiped", "kind": "rect", "fill": "#FF0000", "at": [1, 4], "width": 100, "height": 50, "position": [500, 500],
              "animation": "mine/wipe-in", "motionBlur": true }
            """#
        let sequence = try resolved(clips: [wiped], shutter: #"{ "shutterPhase": -180 }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1.51)

        // Then
        let samples = try #require(list.samples)
        let reveals = try samples.map { try item("wiped", in: $0).reveal }
        let whole = try #require(reveals.last ?? nil)
        let atT = try item("wiped", in: sut.displayListWithoutMotionBlur(of: sequence, at: 1.51).items)
        #expect(reveals.allSatisfy { $0 != nil })
        #expect((reveals.first??.width ?? whole.width) < whole.width)
        #expect(whole.width == 100)
        #expect(atT.reveal == nil)
        #expect(try samples.allSatisfy { try item("back", in: $0).reveal == nil })
    }

    @Test("a wipe on a clip with a corner pin that ends inside the exposure is written in every sample on the item inside its group, not on the group, and the samples read back")
    func keepsPinnedRevealInEverySample() throws {
        // Given
        let wiped = #"""
            { "id": "wiped", "kind": "rect", "fill": "#FF0000", "at": [1, 4], "width": 100, "height": 50,
              "cornerPin": [[400, 400], [600, 420], [580, 560], [420, 540]], "animation": "mine/wipe-in", "motionBlur": true }
            """#
        let sequence = try resolved(clips: [wiped], shutter: #"{ "shutterPhase": -180 }"#)

        // When
        let list = sut.displayList(of: sequence, at: 1.51)

        // Then
        // The group carries the corner pin, and the clip's reveal acts on its plane, on the item inside the group.
        let samples = try #require(list.samples)
        let groups = try samples.map { try item("wiped", in: $0) }
        let inner = groups.compactMap { group -> DisplayItem? in
            guard case let .picture(picture) = group.content, case let .displayList(nested) = picture.source else {
                return nil
            }

            return nested.items.first
        }
        let reveals = inner.map(\.reveal)
        #expect(inner.count == 16)
        #expect(groups.allSatisfy { $0.reveal == nil })
        #expect(reveals.allSatisfy { $0 != nil })
        #expect((reveals.first??.width ?? 0) < (reveals.last??.width ?? 0))
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test(
        "a complete wipe on an adjustment with a feathered or inverted mask, or one its animation moves, is written in every sample as the bounds of what the adjustment draws",
        arguments: [
            (
                #""animation": "mine/wipe-in", "mask": { "kind": "rect", "area": [100, 100, 400, 300], "feather": 8 }"#,
                2.0,
                Rectangle(x: 68, y: 68, width: 464, height: 364) as Rectangle?
            ),
            (
                #""animation": "mine/wipe-in", "mask": { "kind": "ellipse", "area": [100, 100, 400, 300], "invert": true }"#,
                2.0,
                Rectangle(x: 0, y: 0, width: 1920, height: 1080)
            ),
            (#""animation": "mine/drift""#, 0.5, nil)
        ]
    )
    func writesDrawnBoundsOfCompleteAdjustmentWipe(
        written: String,
        time: Double,
        drawn: Rectangle?
    ) throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "id": "back", "kind": "solid", "color": "#202020", "duration": 4 } ],
              "clips": [ { "id": "grade", "kind": "adjustment", "adjust": "mine/grade", "at": [0, 4], "motionBlur": true, \#(written) } ] }
            """#, animations: ["mine/drift": drift])
        let frame = Rectangle(x: 0, y: 0, width: 1920, height: 1080)

        // When
        let list = sut.displayList(of: sequence, at: time)

        // Then
        // A feathered mask lets its adjustment through as far as four times its feather past its box.
        let samples = try #require(list.samples)
        let items = try samples.map { try item("grade", in: $0) }
        #expect(items.allSatisfy { item in
            guard case let .adjust(adjust) = item.content else { return false }

            return item.reveal == adjust.drawnBounds(carriedBy: item.transform, masks: item.mask, over: frame)
        })
        #expect(drawn == nil || items.allSatisfy { $0.reveal == drawn })
        #expect((items.first?.transform == items.last?.transform) == (time == 2))
    }

    @Test("a wipe under way on an adjustment with a hard-edged mask wipes across the mask's box, value for value")
    func wipesBoxOfHardEdgedMask() throws {
        // Given
        let sequence = try resolved(clips: [#"""
            { "id": "grade", "kind": "adjustment", "adjust": "mine/grade", "at": [0, 4], "animation": "mine/wipe-in",
              "mask": { "kind": "rect", "area": [10.1, 20.3, 30.7, 40.9] } }
            """#])
        let box = Rectangle(x: 10.1, y: 20.3, width: 30.7, height: 40.9)

        // When
        let list = sut.displayList(of: sequence, at: 0.25)

        // Then
        #expect(try item("grade", in: list.items).reveal == Reveal(amount: 0.5).rectangle(wiping: box, from: .left))
    }

    @Test("a wipe under way on an adjustment with a feathered mask wipes across the mask's box grown by four times its feather")
    func wipesGrownBoxOfFeatheredMask() throws {
        // Given
        let sequence = try resolved(clips: [#"""
            { "id": "grade", "kind": "adjustment", "adjust": "mine/grade", "at": [0, 4], "animation": "mine/wipe-in",
              "mask": { "kind": "rect", "area": [100, 100, 400, 300], "feather": 8 } }
            """#])

        // When
        let list = sut.displayList(of: sequence, at: 0.25)

        // Then
        #expect(try item("grade", in: list.items).reveal == Rectangle(x: 68, y: 68, width: 232, height: 364))
    }

    @Test("a clip and a storyline entry give the time their values are read at, by their own switch, held in their windows")
    func givesOwnersValueTime() throws {
        // Given
        let sequence = try resolved(clips: [slider(isMotionBlurred: true)])
        let reads = MotionBlurReads()
        let sample = SampleInstant(instant: 4.5, frameTime: 3.99, reads: reads)

        // When
        let clip = sequence.clips[0].valueTime(in: sample)
        let entry = sequence.storyline.valueTime(ofEntry: 0, in: sample)

        // Then
        #expect(clip.instant == TimeRange(start: 0, end: 4).held(4.5))
        #expect(clip.frameTime == 3.99)
        #expect(entry.instant == 3.99)
        #expect(sequence.storyline.drawnRange(ofEntry: 0) == TimeRange(start: 0, end: 4))
        #expect(reads.readsMotionBlur)
    }

    @Test("a read of a value whose owner has no motionBlur is not recorded")
    func recordsNoReadWithoutSwitch() throws {
        // Given
        let sequence = try resolved(clips: [slider(isMotionBlurred: false)])
        let reads = MotionBlurReads()
        let sample = SampleInstant(instant: 4.5, frameTime: 3.99, reads: reads)

        // When
        let clip = sequence.clips[0].valueTime(in: sample)
        let entry = sequence.storyline.valueTime(ofEntry: 0, in: sample)

        // Then
        #expect(clip.instant == 3.99)
        #expect(entry.instant == 3.99)
        #expect(!reads.readsMotionBlur)
    }

    @Test("a step keyframe at 1.53 holds every instant of the frame at 1.52 at the old place")
    func clampsStepKeyframe() throws {
        // Given
        let stepped = #"""
            { "id": "stepped", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "motionBlur": true,
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
        let bar = ##"{ "id": "bar", "kind": "rect", "fill": "#000000", "at": [0, 4], "area": { "clip": "slider", "padding": 10 } }"##
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

    @Test("under speed 2 the nested time moves twice as fast over the exposure, so a clip inside blurs by the motion it shows on the output")
    func carriesSpeedIntoCompound() throws {
        // Given
        // C plays its 4 nested seconds at speed 2 over 0 to 2, so the frame at 0.5 shows X at nested time 1.
        let compound = compoundClip(isMotionBlurred: false, inner: true, at: "[0, 2]", extra: #""in": 0, "out": 4, "speed": 2"#)
        let sequence = try resolved(clips: [compound])

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 0.5).samples)

        // Then
        let at = sut.displayListWithoutMotionBlur(of: sequence, at: 0.5).items
        let innerShifts = try samples.map { try x(of: "x", in: nested(in: $0)) - x(of: "x", in: nested(in: at)) }
        #expect(isClose(innerShifts, offsets.map { -1000 * $0 }))
    }

    @Test("where timeRemap plays backwards the nested times follow it instant by instant, so a clip inside blurs back along its motion")
    func carriesBackwardRemapIntoCompound() throws {
        // Given
        // The remap shows nested time 3 at 0 and 0 at 3, so the frame at 2.5 shows X at nested time 0.5 and each later
        // instant an earlier nested time.
        let remap = #""keyframes": [ { "at": 0, "timeRemap": 3 }, { "at": 3, "timeRemap": 0 } ]"#
        let sequence = try resolved(clips: [compoundClip(isMotionBlurred: false, inner: true, extra: remap)])

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 2.5).samples)

        // Then
        let at = sut.displayListWithoutMotionBlur(of: sequence, at: 2.5).items
        let innerShifts = try samples.map { try x(of: "x", in: nested(in: $0)) - x(of: "x", in: nested(in: at)) }
        #expect(isClose(innerShifts, offsets.map { 500 * $0 }))
    }

    @Test("where timeRemap turns back inside the exposure the nested times it passes twice are read twice")
    func readsTurningRemapTwice() throws {
        // Given
        // The remap plays forwards to nested time 1.01 at 1.01 and back from there, so of the frame at 1, exposed from 1
        // to 1.02, the instants 1.01 - u and 1.01 + u show one nested time: samples i and 15 - i.
        let remap = #""keyframes": [ { "at": 0, "timeRemap": 0 }, { "at": 1.01, "timeRemap": 1.01 }, { "at": 2.02, "timeRemap": 0 } ]"#
        let sequence = try resolved(clips: [compoundClip(isMotionBlurred: false, inner: true, extra: remap)])

        // When
        let samples = try #require(sut.displayList(of: sequence, at: 1).samples)

        // Then
        let at = sut.displayListWithoutMotionBlur(of: sequence, at: 1).items
        let innerShifts = try samples.map { try x(of: "x", in: nested(in: $0)) - x(of: "x", in: nested(in: at)) }
        let turned = offsets.map { -500 * min($0, 0.02 - $0) }
        #expect(isClose(innerShifts, turned))
        #expect(isClose(innerShifts, innerShifts.reversed()))
    }

    @Test("a keyframed displace offset with motionBlur takes in each sample its value at that sample's instant, and the samples read back")
    func movesDisplaceOffsetInEverySample() throws {
        // Given
        let sequence = try resolved(clips: [#"""
            { "id": "leaf", "kind": "media", "media": "/abs/card.png", "at": [0, 4], "motionBlur": true,
              "filter": { "kind": "displace", "file": "/abs/matte.png", "amount": 8 },
              "keyframes": [ { "at": 0, "filter": { "offset": [0, 0] } }, { "at": 2, "filter": { "offset": [400, -200] } } ] }
            """#])
        let list = sut.displayList(of: sequence, at: 1)

        // When
        let read = try DisplayListReader().read(DisplayListWriter().write(list))

        // Then
        let samples = try #require(list.samples)
        let moved = samples.map { displaceOffsets(in: $0) }
        let expected = offsets.map { displaceOffsets(in: sut.displayListWithoutMotionBlur(of: sequence, at: 1 + $0).items) }
        #expect(moved.allSatisfy { $0.count == 1 })
        #expect(isClose(moved.flatMap { $0.flatMap { [$0.x, $0.y] } }, expected.flatMap { $0.flatMap { [$0.x, $0.y] } }))
        #expect(moved.first != moved.last)
        #expect(read.samples?.count == 16)
    }

    @Test("a path with keyframed points and motionBlur takes in each sample its vertices at that sample's instant, and the samples read back")
    func movesPathPointsInEverySample() throws {
        // Given
        let sequence = try resolved(clips: [#"""
            { "id": "leaf", "kind": "path", "stroke": { "width": 4, "paint": "#FFFFFF" }, "at": [0, 4], "motionBlur": true,
              "keyframes": [ { "at": 0, "points": [[0, 0], [100, 0], [100, 100]] }, { "at": 2, "points": [[0, 0], [300, 0], [300, 400]] } ] }
            """#])
        let list = sut.displayList(of: sequence, at: 1)

        // When
        let read = try DisplayListReader().read(DisplayListWriter().write(list))

        // Then
        let samples = try #require(list.samples)
        let moved = try samples.map { try vertices(of: "leaf", in: $0) }
        let expected = try offsets.map { try vertices(of: "leaf", in: sut.displayListWithoutMotionBlur(of: sequence, at: 1 + $0).items) }
        #expect(moved.allSatisfy { $0.count == 3 })
        #expect(isClose(moved.flatMap { $0.flatMap { [$0.x, $0.y] } }, expected.flatMap { $0.flatMap { [$0.x, $0.y] } }))
        #expect(moved.first != moved.last)
        #expect(read.samples?.count == 16)
    }

    @Test("an edit point on a frame boundary is the frame's membership: the incoming clip draws in every sample at 2, the outgoing one at 1.96")
    func keepsCutAtEditPoint() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "id": "a", "kind": "solid", "color": "#202020", "duration": 2, "motionBlur": true },
                             { "id": "b", "kind": "solid", "color": "#404040", "duration": 2, "motionBlur": true } ] }
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
              "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "in": 0, "out": 4, "motionBlur": true,
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

    @Test("a page with motionBlur and a keyframed scale shows the one page in every sample, and the samples read back")
    func showsOnePage() throws {
        // Given
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "kind": "media", "media": "/abs/logo.pdf", "duration": 4, "motionBlur": true,
                               "keyframes": [ { "at": 0, "scale": 1 }, { "at": 4, "scale": 2 } ] } ] }
            """#)
        let list = sut.displayList(of: sequence, at: 1.03)

        // When
        let read = try DisplayListReader().read(DisplayListWriter().write(list))

        // Then
        let samples = try #require(read.samples)
        let frames = samples.map { mediaFrame(in: $0) }
        #expect(samples.count == 16)
        #expect(frames.allSatisfy { $0?.picture == .page && $0 == frames[0] })
        #expect(frames[0] == mediaFrame(in: sut.displayListWithoutMotionBlur(of: sequence, at: 1.03).items))
        #expect(samples[0] != samples[15])
    }

    @Test("a clip with motionBlur whose crop tracks its media is carried by the motion of the media frame of T in every sample")
    func carriesTrackedCropAtT() throws {
        // Given
        // The exposure of the frame at 0.99 crosses from the media frame at 0.9 to the one at 1, whose motions differ by
        // 10 pixels.
        let sequence = try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 2, "crop": [100, 100, 200, 40], "track": \#(driftingTrack), "motionBlur": true } ] }
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
                  "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4", "in": 0, "out": 2, "connected": [
                    { "id": "box", "kind": "rect", "stroke": { "width": 8 }, "parent": "screen", "at": [0, 2], "area": [100, 100, 200, 40],
                      "track": \#(driftingTrack), "motionBlur": \#(isMotionBlurred) } ] } ] }
                """#
        }
        let blurred = try resolved(document(true))
        let sharp = try resolved(document(false))

        // When
        let samples = try #require(sut.displayList(of: blurred, at: 0.99).samples)

        // Then
        let target = try bounds(of: "box", in: sut.displayList(of: sharp, at: 0.99).items)
        let next = try bounds(of: "box", in: sut.displayList(of: sharp, at: 1).items)
        let drawn = try samples.map { try bounds(of: "box", in: $0) }
        #expect(drawn.allSatisfy { isClose([$0.x, $0.y, $0.width, $0.height], [target.x, target.y, target.width, target.height]) })
        #expect(abs(next.x - target.x) > 1)
    }

    @Test("a list given as samples stops a report, since an item has no one place in an exposure")
    func refusesToReportSamples() throws {
        // Given
        let list = sut.displayList(of: try resolved(clips: [slider(isMotionBlurred: true)]), at: 1)

        // When
        let report = { try EvaluationReporter().report(of: list, at: 1) }

        // Then
        #expect(throws: AnalysisError.sampledList) { try report() }
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

    @Test("a title by unit with motionBlur mid entrance gives samples whose extents move with its tracking, and the samples read back")
    func readsBackTitleByUnit() throws {
        // Given
        let sequence = try title(isMotionBlurred: true)

        // When
        let list = sut.displayList(of: sequence, at: 0.1)

        // Then
        let samples = try #require(list.samples)
        let units = try samples.map { try glyphs(of: "title", in: $0).filter { $0.unit != nil } }
        // Each of the four passes draws the units "a", "b ", "c" and "d" in reading order.
        #expect(units.allSatisfy { $0.compactMap(\.unit?.index) == Array(repeating: [0, 1, 2, 3], count: 4).flatMap { $0 } })
        #expect(units.first?.map(\.extent) != units.last?.map(\.extent))
        #expect(try DisplayListReader().read(DisplayListWriter().write(list)).samples?.count == 16)
    }

    @Test("evaluate reports a title by unit with motionBlur mid entrance as at T, its characters and texts those without motion blur")
    func reportsTitleByUnitAtT() throws {
        // Given
        let blurred = try title(isMotionBlurred: true)
        let sharp = try title(isMotionBlurred: false)

        // When
        let report = try EvaluationReporter().report(of: blurred, at: 0.1)

        // Then
        #expect(report.items.compactMap(\.characters).flatMap { $0 }.map(\.text) == ["a", "b", " ", "c", "d"])
        #expect(report.texts.count == 1)
        #expect(report == (try EvaluationReporter().report(of: sharp, at: 0.1)))
    }

    // MARK: - Private
    // Slides right at 500 pixels a second, from 100 at 0 to 1100 at 2.
    private func slider(isMotionBlurred: Bool) -> String {
        #"""
            { "id": "slider", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50, "motionBlur": \#(isMotionBlurred),
              "keyframes": [ { "at": 0, "position": [100, 500] }, { "at": 2, "position": [1100, 500] } ] }
            """#
    }

    // "ab cd" fading in by character from 0, its tracking keyframed from 0 at 0 to 100 at 1.
    private func title(isMotionBlurred: Bool) throws -> ResolvedSequence {
        try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25 },
              "theme": { "styles": { "caption": { "size": 40, "color": "#000000" } } },
              "storyline": [ { "id": "back", "kind": "solid", "color": "#202020", "duration": 4 } ],
              "clips": [ { "id": "title", "kind": "title", "text": "ab cd", "style": "caption", "position": [400, 225], "at": [0, 2],
                           "motionBlur": \#(isMotionBlurred), "animation": { "preset": "frames/fade", "by": "character" },
                           "keyframes": [ { "at": 0, "character": { "tracking": 0 } }, { "at": 1, "character": { "tracking": 100 } } ] } ] }
            """#)
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
            { "id": "child", "kind": "rect", "fill": "#00FF00", "at": [0, 4], "parent": "slider", "position": [0, 0],
              "motionBlur": \#(isMotionBlurred), \#(size) }
            """#
    }

    // C slides right at 500 pixels a second over `at` and X inside it left at 500 a second of its nested time, from 1500
    // at 0 to 500 at 2, while Y inside it stands still. `extra` takes the place of C's keyframes.
    private func compoundClip(
        isMotionBlurred: Bool,
        inner: Bool,
        at: String = "[0, 4]",
        extra: String? = nil
    ) -> String {
        let keyframes = extra ?? #""keyframes": [ { "at": 0, "position": [460, 540] }, { "at": 2, "position": [1460, 540] } ]"#
        return #"""
            { "id": "c", "at": \#(at), "motionBlur": \#(isMotionBlurred), \#(keyframes),
              "kind": "media",
              "media": { "kind": "sequence", "format": { "size": [1920, 1080] },
                         "storyline": [ { "kind": "solid", "color": "#000000", "duration": 4 } ],
                         "clips": [ { "id": "x", "kind": "rect", "fill": "#FF0000", "at": [0, 4], "width": 100, "height": 50,
                                      "motionBlur": \#(inner),
                                      "keyframes": [ { "at": 0, "position": [1500, 500] }, { "at": 2, "position": [500, 500] } ] },
                                    { "id": "y", "kind": "rect", "fill": "#00FF00", "at": [0, 4], "width": 100, "height": 50,
                                      "position": [300, 300] } ] } }
            """#
    }

    // Under the default shutter, or under `shutter` written as the format's `motionBlur`.
    private func resolved(
        clips: [String],
        shutter: String? = nil
    ) throws -> ResolvedSequence {
        let motionBlur = shutter.map { #", "motionBlur": \#($0)"# } ?? ""
        return try resolved(#"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 25\#(motionBlur) },
              "storyline": [ { "id": "back", "kind": "solid", "color": "#202020", "duration": 4 } ], "clips": [ \#(clips.joined(separator: ", ")) ] }
            """#)
    }

    private func resolved(_ document: String) throws -> ResolvedSequence {
        try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    // Resolved with `animations` beside the fixture's presets.
    private func resolved(
        _ document: String,
        animations: [String: AnimationPreset]
    ) throws -> ResolvedSequence {
        let presets = PresetTable(
            transitions: Fixture.presets.transitions,
            animations: Fixture.presets.animations.merging(animations) { $1 },
            filters: Fixture.presets.filters,
            audio: Fixture.presets.audio
        )
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets,
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
                content: .solid(ResolvedSolid(
                    color: [Keyframe(at: start, value: Color(written: "#000000"))],
                    size: size,
                    conform: .fit
                )),
                in: 0,
                out: end - start,
                speed: 1,
                start: start,
                end: end,
                isMotionBlurred: isMotionBlurred,
                transition: transition
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

    // The keys a written value holds at every depth, each leaf and `null` kept apart and every other value one mark.
    private func keys(of value: JSONValue) -> JSONValue {
        switch value {
        case .null:
            .null

        case let .object(object):
            .object(JSONObject(members: object.members.map { JSONMember(key: $0.key, value: keys(of: $0.value)) }))

        case let .array(elements):
            .array(elements.map(keys(of:)))

        case .bool, .number, .string:
            .bool(true)
        }
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

    // The glyphs items the clip at `id` draws, those of the list its picture holds for a title by unit.
    private func glyphs(
        of id: String,
        in items: [DisplayItem]
    ) throws -> [GlyphsItem] {
        try items.filter { $0.origin?.id == id }.flatMap { item in
            switch item.content {
            case let .glyphs(glyphs):
                return [glyphs]

            case let .picture(picture):
                guard case let .displayList(list) = picture.source else { return [] }

                return try glyphs(of: id, in: list.items)

            case .path, .adjust:
                return []
            }
        }
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

    // The offset of every `displace` op of every picture in `items`, nested lists included.
    private func displaceOffsets(in items: [DisplayItem]) -> [Point] {
        items.flatMap { item -> [Point] in
            guard case let .picture(picture) = item.content else { return [] }

            let own = picture.filter.flatMap(\.operations).compactMap { operation -> Point? in
                guard case let .displace(_, _, offset) = operation else { return nil }

                return offset
            }
            guard case let .displayList(list) = picture.source else { return own }

            return own + displaceOffsets(in: list.items)
        }
    }

    // The vertices of the path the clip at `id` draws, in its item's coordinates.
    private func vertices(
        of id: String,
        in items: [DisplayItem]
    ) throws -> [Point] {
        guard case let .path(path) = try item(id, in: items).content, case let .path(vertices, _) = path.geometry else {
            Issue.record("the clip draws no path of vertices")
            return []
        }

        return vertices.map(\.vertex)
    }

    private func isClose(
        _ values: [Double],
        _ expected: [Double]
    ) -> Bool {
        values.count == expected.count && zip(values, expected).allSatisfy { abs($0 - $1) < 1e-6 }
    }
}
