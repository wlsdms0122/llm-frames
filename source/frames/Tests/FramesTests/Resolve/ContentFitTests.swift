//
//  ContentFitTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

// `/abs/page.png` is 1000 by 800 and `/abs/card.png` 1080 by 1350. A content-fit frame on `page.png` sets a title at
// the length scale 1000 / 1920, so a letter of the base `title` style, 96 at the fake shaper's 0.5 em, is 25 wide.
@Suite("ContentFit Tests")
struct ContentFitTests {
    // MARK: - Property
    private let sut = Fixture.sequencePlanner

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a storyline picture keeps the pixel size of its crop at scale 1, its top left at the origin",
        arguments: [
            (#""crop": [100, 50, 300, 200]"#, Size(width: 300, height: 200)),
            (#""crop": { "scale": 2 }"#, Size(width: 500, height: 400)),
            (#""anchor": "top-left""#, Size(width: 1000, height: 800))
        ]
    )
    func keepsStorylineCropSize(
        crop: String,
        size: Size
    ) throws {
        // When
        let plan = try plan(#"{ "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1, \#(crop) } ] }"#)

        // Then
        #expect(plan.format.size == size)
        let box = plan.storyline[0].appearance.box
        #expect(box?.size == size)
        #expect(box?.position == box.map { .value(.point($0.anchor)) })
    }

    @Test("a later storyline crop conforms to the box of the first, which does not scale it to the frame")
    func conformsLaterCropToBox() throws {
        // Given
        let plan = try plan(#"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 2,
              "keyframes": [ { "at": 0, "crop": [0, 0, 400, 200] }, { "at": 1, "crop": [0, 0, 100, 100] } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: PlaceholderHasher())

        // Then
        #expect(plan.format.size == Size(width: 400, height: 200))
        #expect(resolved.storyline[0].placement.size == Size(width: 400, height: 200))
        #expect(resolved.storyline[0].crop.values == [
            Crop(Rectangle(x: 0, y: 0, width: 400, height: 200)),
            Crop(Rectangle(x: -50, y: 0, width: 200, height: 100))
        ])
    }

    @Test("a media clip without a size is the pixel size of its first crop or of its media, its top left at the origin")
    func measuresMediaClipAtPixelSize() throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1 } ],
              "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1] },
                         { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "crop": [0, 0, 200, 100], "position": [1500, 50] } ] }
            """#)

        // Then
        #expect(plan.clips[0].box == ClipBox(
            size: Size(width: 1080, height: 1350),
            position: .value(Point(x: 540, y: 675)),
            anchor: Point(x: 540, y: 675)
        ))
        #expect(plan.clips[1].box?.size == Size(width: 200, height: 100))
        #expect(plan.format.size == Size(width: 1600, height: 1350))
    }

    @Test(
        "a title is measured by its text box where its position puts it, its width or fitted to its text without one",
        arguments: [(#""width": 2000, "#, 2000.0), ("", 125)] as [(String, Double)]
    )
    func measuresTitle(
        width: String,
        boxWidth: Double
    ) throws {
        // Given
        let plan = try plan(#"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1 } ],
              "clips": [ { "kind": "title", "text": "Hello", "style": "title", \#(width)"at": [0, 1], "position": [1200, 0], "anchor": "top-left" } ] }
            """#)
        let box = try #require(plan.clips[0].box)

        // When
        let right = (1200 + box.size.width).rounded(.up)

        // Then
        #expect(box.size.width == boxWidth)
        #expect(box.position == .value(.point(Point(x: 1200, y: 0))))
        #expect(plan.format.size == Size(width: (right / 2).rounded(.up) * 2, height: 800))
    }

    @Test("a title is measured with its highlights, which may reach past its text box")
    func measuresTitleHighlight() throws {
        // Given
        let plan = try plan(#"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1 } ],
              "clips": [ { "kind": "title", "text": "Hello", "style": "title", "at": [0, 1], "position": [1200, 0], "anchor": "top-left",
                           "character": { "highlight": { "padding": [0, 96] } } } ] }
            """#)

        // When
        let size = plan.format.size

        // Then
        // The padding is 96 theme lengths, 50 output pixels at the length scale, past the 125 wide box.
        #expect(size == Size(width: 1376, height: 800))
    }

    @Test("a clip used as a track matte is not drawn, so it is not measured")
    func skipsTrackMatte() throws {
        // Given
        let matte = #"{ "id": "m", "kind": "media", "media": "/abs/card.png", "at": [0, 1], "crop": [0, 0, 200, 100], "position": [1500, 50] }"#
        let rect = ##"{ "kind": "rect", "fill": "#FFFFFF", "area": [0, 0, 10, 10], "at": [0, 1]"##
        let storyline = #"{ "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1 } ], "clips": "#

        // When
        let matted = try plan(storyline + #"[ \#(matte), \#(rect), "trackMatte": { "clip": "m", "mode": "alpha" } } ] }"#)
        let alone = try plan(storyline + #"[ \#(rect) } ] }"#)
        let drawn = try plan(storyline + #"[ \#(matte), \#(rect) } ] }"#)

        // Then
        #expect(matted.format.size == alone.format.size)
        #expect(drawn.format.size.width > alone.format.size.width)
    }

    @Test("a parented child is measured through its parent's geometry, and stays where it is in its parent's space")
    func measuresParentedChild() throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "id": "page", "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [100, 100, 400, 300],
              "connected": [ { "kind": "rect", "fill": "#FFD43B80", "parent": "page", "area": [50, 50, 100, 100] } ] } ] }
            """#)

        // Then
        #expect(plan.format.size == Size(width: 450, height: 350))
        #expect(plan.storyline[0].appearance.box?.position == .value(.point(Point(x: 250, y: 200))))
        #expect(plan.clips[0].area?.firstValue.rectangle == Rectangle(x: 50, y: 50, width: 100, height: 100))
    }

    @Test(
        "the margin is added round the content in each of its forms, which moves the content by its left and top",
        arguments: [
            ("10", Size(width: 320, height: 220), Point(x: 160, y: 110)),
            ("[10, 20]", Size(width: 340, height: 220), Point(x: 170, y: 110)),
            ("[2, 4, 6, 8]", Size(width: 312, height: 208), Point(x: 158, y: 102))
        ]
    )
    func addsMargin(
        margin: String,
        size: Size,
        position: Point
    ) throws {
        // When
        let plan = try plan(
            #"{ "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ] }"#,
            margin: margin
        )

        // Then
        #expect(plan.format.size == size)
        #expect(plan.format.margin != nil)
        #expect(plan.storyline[0].appearance.box?.position == .value(.point(position)))
    }

    @Test(
        "the union is rounded outward to whole pixels and each side up to an even number",
        arguments: [
            (#""crop": [0, 0, 301, 199]"#, "0", Size(width: 302, height: 200)),
            (#""crop": [0, 0, 300, 200]"#, "[0, 1, 0, 0]", Size(width: 302, height: 200)),
            (#""crop": [0, 0, 300, 200], "position": [150.5, 100.25]"#, "0", Size(width: 302, height: 202))
        ]
    )
    func roundsToEvenSize(
        crop: String,
        margin: String,
        size: Size
    ) throws {
        // When
        let plan = try plan(#"{ "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1, \#(crop) } ] }"#, margin: margin)

        // Then
        #expect(plan.format.size == size)
    }

    @Test("every unparented clip and storyline picture is moved by the offset that puts the content's top left at the margin")
    func movesByOffset() throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ],
              "clips": [ { "kind": "rect", "fill": "#FFD43B80", "area": [-100.5, -50, 50, 50], "at": [0, 1] },
                         { "kind": "media", "media": "/abs/card.png", "width": 100, "height": 100, "at": [0, 1], "position": [0, 0] } ] }
            """#, margin: "4")

        // Then
        #expect(plan.format.size == Size(width: 410, height: 258))
        #expect(plan.storyline[0].appearance.box?.position == .value(.point(Point(x: 255, y: 154))))
        #expect(plan.clips[0].area?.firstValue.rectangle == Rectangle(x: 4.5, y: 4, width: 50, height: 50))
        #expect(plan.clips[1].position == .value(.point(Point(x: 105, y: 54))))
        #expect(plan.clips[1].box?.position == .value(.point(Point(x: 105, y: 54))))
    }

    @Test("a solid fills the measured frame and is not measured")
    func fillsMeasuredFrameWithSolid() throws {
        // Given
        let plan = try plan(##"""
            { "storyline": [ { "kind": "solid", "color": "#FF0000", "duration": 1 }, { "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ] }
            """##, margin: "10")

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: PlaceholderHasher())

        // Then
        #expect(plan.format.size == Size(width: 320, height: 220))
        #expect(plan.storyline[0].appearance.box == nil)
        guard case let .transform(box, _, _) = resolved.storyline[0].placement else {
            Issue.record("the solid is placed by a corner pin")
            return
        }
        #expect(box == ResolvedBox(
            size: Size(width: 320, height: 220),
            position: [Keyframe(at: 0, value: Point(x: 160, y: 110))],
            anchor: Point(x: 160, y: 110)
        ))
    }

    @Test("a solid's transform is the identity, so its children are drawn where they were measured, moved by the offset")
    func drawsSolidChildWhereMeasured() throws {
        // Given
        let plan = try plan(##"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] },
              { "id": "back", "kind": "solid", "color": "#FF0000", "duration": 1,
                "connected": [ { "kind": "rect", "fill": "#FFD43B80", "parent": "back", "area": [-100, -50, 50, 50] } ] } ] }
            """##, margin: "4")

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: PlaceholderHasher())
        let space = ParentEvaluator(sequence: resolved).space(of: resolved.clips[0], at: SampleTime(0))

        // Then
        #expect(plan.format.size == Size(width: 408, height: 258))
        #expect(plan.storyline[0].appearance.box?.position == .value(.point(Point(x: 254, y: 154))))
        #expect(plan.clips[0].area?.firstValue.rectangle == Rectangle(x: 4, y: 4, width: 50, height: 50))
        #expect(space.transform == .identity)
    }

    @Test("a solid's children are in the measuring space, which has no edges, so an area outside the first box grows the frame")
    func measuresSolidChildOutsideFirstBox() throws {
        // When
        let plan = try plan(##"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] },
              { "id": "back", "kind": "solid", "color": "#FF0000", "duration": 1,
                "connected": [ { "kind": "rect", "fill": "#FFD43B80", "parent": "back", "area": [400, 0, 50, 50] } ] } ] }
            """##)

        // Then
        #expect(plan.format.size == Size(width: 450, height: 200))
        #expect(plan.clips[0].area?.firstValue.rectangle == Rectangle(x: 400, y: 0, width: 50, height: 50))
    }

    @Test("theme lengths take the length scale of the first storyline picture's box")
    func scalesByFirstStorylinePicture() throws {
        // When
        let plan = try plan(##"""
            { "storyline": [ { "kind": "solid", "color": "#FF0000", "duration": 1 }, { "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 603, 400] } ],
              "clips": [ { "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 100, 100], "at": [0, 1] } ] }
            """##)

        // Then
        let scale = MergedTheme.base.lengthScale(at: 603)
        #expect(plan.clips[0].appearance.shape?.stroke.stroke()?.width == 8 * scale)
    }

    @Test(
        "a clip placed by its placement or its style's lies on the measured frame where that placement puts it, with its style's offset, and is not measured",
        arguments: [
            // The subtitle style places at the bottom, 108 theme lengths up, 56.25 output pixels at the length scale.
            (#"{ "kind": "title", "text": "Hi", "style": "subtitle", "at": [0, 1] }"#, Point(x: 510, y: 763.75)),
            // The placement padding is 96 theme lengths, 50 output pixels.
            (#"{ "kind": "title", "text": "Hi", "style": "title", "placement": "bottom-right", "at": [0, 1] }"#, Point(x: 970, y: 770)),
            (#"{ "kind": "media", "media": "/abs/card.png", "width": 2000, "placement": "top-left", "at": [0, 1] }"#, Point(x: 50, y: 50)),
            (#"{ "kind": "rect", "width": 100, "height": 50, "fill": "accent", "placement": "center", "at": [0, 1] }"#, Point(x: 510, y: 410))
        ]
    )
    func placesOnMeasuredFrame(
        clip: String,
        position: Point
    ) throws {
        // When
        let plan = try plan(
            #"{ "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1 } ], "clips": [ \#(clip) ] }"#,
            margin: "10"
        )

        // Then
        #expect(plan.format.size == Size(width: 1020, height: 820))
        #expect(plan.storyline[0].appearance.box?.position == .value(.point(Point(x: 510, y: 410))))
        #expect(plan.clips[0].box?.position == .value(.point(position)))
    }

    @Test("a clip parented to a clip placed by its placement, or taking its box through a clip area, follows it and is not measured")
    func followsClipPlacedOnFrame() throws {
        // Given
        let plan = try plan(##"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1 } ],
              "clips": [ { "id": "sub", "kind": "title", "text": "Hi", "style": "subtitle", "at": [0, 1] },
                         { "kind": "rect", "fill": "#FFD43B80", "parent": "sub", "area": [0, 0, 4000, 10], "at": [0, 1] },
                         { "kind": "rect", "fill": "#FFD43B80", "area": { "clip": "sub", "padding": 2000 }, "at": [0, 1] } ] }
            """##, margin: "10")
        let box = try #require(plan.clips[0].box)

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: PlaceholderHasher())
        let space = ParentEvaluator(sequence: resolved).space(of: resolved.clips[1], at: SampleTime(0))

        // Then
        #expect(plan.format.size == Size(width: 1020, height: 820))
        #expect(space.transform.apply(to: Point(x: 0, y: 0)) == Point(
            x: 510 - box.size.width / 2,
            y: 763.75 - box.size.height
        ))
        #expect(plan.clips[2].area?.firstValue == .clip(ClipArea(clip: "sub", padding: 2000 * (1000 / 1920.0))))
    }

    @Test("a clip area naming a storyline picture takes the box measured at the picture's pixel size, so the clip is measured and grows the frame")
    func measuresClipAreaOnStorylinePicture() throws {
        // Given
        let plan = try plan(##"""
            { "storyline": [ { "id": "page", "kind": "media", "media": "/abs/page.png", "duration": 1 } ],
              "clips": [ { "kind": "rect", "fill": "#FFD43B80", "area": { "clip": "page", "padding": 192 }, "at": [0, 1] } ] }
            """##)

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: PlaceholderHasher())
        let item = try #require(Evaluator().displayList(of: resolved, at: 0).items.last { $0.origin?.kind == "rect" })
        guard case let .path(path) = item.content, case let .rect(rectangle, _) = path.geometry else {
            Issue.record("the clip draws no rect")
            return
        }

        // Then
        // The length scale is 1000 / 1920, so the padding is 100 output pixels round the 1000 by 800 box.
        #expect(plan.format.size == Size(width: 1200, height: 1000))
        #expect(plan.storyline[0].appearance.box?.position == .value(.point(Point(x: 600, y: 500))))
        #expect(Rectangle(bounding: item.transform.apply(toCornersOf: rectangle)) == Rectangle(x: 0, y: 0, width: 1200, height: 1000))
    }

    @Test("a box with neither a position nor a placement, its style's included, sits with its top left at the origin and is measured")
    func measuresUnplacedTitle() throws {
        // When
        let plan = try plan(#"""
            { "theme": { "styles": { "plain": { "size": 96 } } },
              "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1 } ],
              "clips": [ { "kind": "title", "text": "Hello", "style": "plain", "width": 1500, "at": [0, 1] } ] }
            """#)
        let box = try #require(plan.clips[0].box)

        // Then
        #expect(box.placement == nil)
        #expect(box.position == .value(.point(box.anchor)))
        #expect(box.anchor == Point(x: 750, y: box.size.height / 2))
        #expect(plan.format.size == Size(width: 1500, height: 800))
    }

    @Test(
        "a storyline of solids leaves nothing to measure and no length scale, so it stops, whatever its other clips",
        arguments: [
            ##"{ "kind": "rect", "fill": "#FFD43B80", "area": [0, 0, 100, 100], "at": [0, 1] }"##,
            #"{ "kind": "title", "text": "Hi", "style": "subtitle", "at": [0, 1] }, { "kind": "media", "media": "/abs/card.png", "placement": "center", "at": [0, 1] }"#
        ]
    )
    func refusesNothingMeasured(clips: String) throws {
        // Given
        let document = ##"{ "storyline": [ { "kind": "solid", "color": "#FF0000", "duration": 1 } ], "clips": [ \##(clips) ] }"##

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"format.size (sequence): every storyline clip is a solid, so a frame measured from the content has nothing to measure and no length scale, and the format needs "size""#)
    }

    @Test("a compound clip whose sequence fits its content has the measured size as its own frame size")
    func takesMeasuredSizeOfCompoundClip() throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "kind": "media", "media": { "kind": "sequence", "format": { "size": { "fit": "content", "margin": 5 } },
              "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ] } } ] }
            """#)

        // Then
        #expect(plan.format.size == Size(width: 310, height: 210))
    }

    @Test(
        "a shape is measured by its outline after its transform, grown by half its stroke width, with its arrowheads",
        arguments: [
            // The page is 300 wide, so a stroke of 64 is 10 output pixels and its arrowhead 40 long and 40 wide.
            (#"{ "kind": "rect", "area": [400, 0, 100, 50], "stroke": { "width": 64 }, "at": [0, 1] }"#, Size(width: 506, height: 206)),
            // A whole closed outline has no ends, so its arrowhead is drawn only where a trim leaves part of it undrawn.
            (#"{ "kind": "rect", "area": [400, 0, 100, 50], "stroke": { "width": 64, "end": "frames/arrow" }, "at": [0, 1] }"#, Size(width: 506, height: 206)),
            // Ending at the bottom right corner, the head points down from (500, 50), its base corners at (480, 10) and
            // (520, 10), so nothing of it lies above the stroked outline.
            (#"{ "kind": "rect", "area": [400, 0, 100, 50], "stroke": { "width": 64, "end": "frames/arrow" }, "trim": [0, 0.5], "at": [0, 1] }"#, Size(width: 520, height: 206)),
            // Ending 1 below the top right corner at the tip (500, 1), the head's base lies 40 back along the stroke at
            // (461, 0), so the head runs along the chord between them, grown to it, a base corner at (461.5, -19.5).
            (#"{ "kind": "rect", "area": [400, 0, 100, 50], "stroke": { "width": 64, "end": "frames/arrow" }, "trim": [0, 0.3366666666666667], "at": [0, 1] }"#, Size(width: 506, height: 220)),
            // A fifth of the way round from its top, the ellipse's head runs along the chord from its base 40 back
            // along the curve, at (458.4, 0.4), to its tip at (495.1, 14.2), 39.3 long, so the head is 39.3 / 40 of its
            // size on a straight end and a base corner lies at (465.4, -18.0).
            (#"{ "kind": "ellipse", "area": [400, 0, 100, 50], "stroke": { "width": 64, "end": "frames/arrow" }, "trim": [0, 0.2], "at": [0, 1] }"#, Size(width: 506, height: 218)),
            (#"{ "kind": "path", "points": [[400, 0], [400, 100]], "stroke": { "width": 64 }, "at": [0, 1] }"#, Size(width: 406, height: 206)),
            (#"{ "kind": "path", "points": [[400, 0], [400, 100]], "stroke": { "width": 64, "end": "frames/arrow" }, "at": [0, 1] }"#, Size(width: 420, height: 206)),
            // At scale 2 the arrowhead is 80 long and 80 wide, and a bar is 40 across the end.
            (#"{ "kind": "path", "points": [[400, 0], [400, 100]], "stroke": { "width": 64, "end": { "preset": "frames/arrow", "scale": 2 } }, "at": [0, 1] }"#, Size(width: 440, height: 206)),
            (#"{ "kind": "path", "points": [[400, 0], [400, 100]], "stroke": { "width": 64, "end": "frames/bar" }, "at": [0, 1] }"#, Size(width: 420, height: 206)),
            // A circle at scale 2 is 80 across with its tip at the end (400, 250), its centre 40 back: it reaches down to
            // y = 290 and no further along the line than its end, which the stroke's half width reaches past.
            (#"{ "kind": "path", "points": [[100, 250], [400, 250]], "stroke": { "width": 64, "end": { "preset": "frames/circle", "scale": 2 } }, "at": [0, 1] }"#, Size(width: 406, height: 290)),
            // Both tangents (100, 0) bulge the segment right to x = 475 at its middle, where the stroke reaches 480.
            (#"{ "kind": "path", "points": [{ "vertex": [400, 0], "outTangent": [100, 0] }, { "vertex": [400, 100], "inTangent": [100, 0] }], "stroke": { "width": 64 }, "at": [0, 1] }"#, Size(width: 480, height: 206)),
            (#"{ "kind": "rect", "area": [400, 0, 100, 50], "fill": "accent", "scale": 2, "at": [0, 1] }"#, Size(width: 550, height: 226)),
            (#"{ "kind": "ellipse", "width": 100, "height": 50, "position": [400, 250], "fill": "accent", "at": [0, 1] }"#, Size(width: 450, height: 276))
        ]
    )
    func measuresShape(
        clip: String,
        size: Size
    ) throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "kind": "media", "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ], "clips": [ \#(clip) ] }
            """#)

        // Then
        #expect(plan.format.size == size)
    }

    // MARK: - Private
    // `body` is the rest of a sequence whose format fits its content with `margin`.
    private func plan(
        _ body: String,
        margin: String = "0"
    ) throws -> SequencePlan {
        let format = #"{ "kind": "sequence", "format": { "size": { "fit": "content", "margin": \#(margin) } }, "#
        return try sut.plan(Fixture.planner.plan(document: Fixture.json(format + body.dropFirst())))
    }
}
