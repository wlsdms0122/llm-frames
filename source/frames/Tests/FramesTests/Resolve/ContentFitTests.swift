//
//  ContentFitTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

// `/abs/page.png` is 1000 by 800 and `/abs/card.png` 1080 by 1350.
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
        let plan = try plan(#"{ "storyline": [ { "media": "/abs/page.png", "duration": 1, \#(crop) } ] }"#)

        // Then
        #expect(plan.format.size == size)
        #expect(plan.storyline[0].appearance.box?.size == size)
        #expect(plan.storyline[0].appearance.box?.position == .value(Point(x: 0, y: 0)))
    }

    @Test("a later storyline crop conforms to the box of the first, which does not scale it to the frame")
    func conformsLaterCropToBox() throws {
        // Given
        let plan = try plan(#"""
            { "storyline": [ { "media": "/abs/page.png", "duration": 2,
              "keyframes": [ { "at": 0, "crop": [0, 0, 400, 200] }, { "at": 1, "crop": [0, 0, 100, 100] } ] } ] }
            """#)

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: PlaceholderHasher())

        // Then
        #expect(plan.format.size == Size(width: 400, height: 200))
        #expect(resolved.storyline[0].box.size == Size(width: 400, height: 200))
        #expect(resolved.storyline[0].crop.map(\.value) == [
            Crop(Rectangle(x: 0, y: 0, width: 400, height: 200)),
            Crop(Rectangle(x: -50, y: 0, width: 200, height: 100))
        ])
    }

    @Test("a media clip without a size is the pixel size of its first crop or of its media, its top left at the origin")
    func measuresMediaClipAtPixelSize() throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "media": "/abs/page.png", "duration": 1 } ],
              "clips": [ { "media": "/abs/card.png", "at": [0, 1] },
                         { "media": "/abs/card.png", "at": [0, 1], "crop": [0, 0, 200, 100], "position": [1500, 50] } ] }
            """#)

        // Then
        #expect(plan.clips[0].box == ClipBox(
            size: Size(width: 1080, height: 1350),
            position: .value(Point(x: 0, y: 0)),
            anchor: Point(x: 540, y: 675)
        ))
        #expect(plan.clips[1].box?.size == Size(width: 200, height: 100))
        #expect(plan.format.size == Size(width: 1600, height: 1350))
    }

    @Test("a title with a width is measured by its text box where its position puts it")
    func measuresTitleWithWidth() throws {
        // Given
        let plan = try plan(#"""
            { "storyline": [ { "media": "/abs/page.png", "duration": 1 } ],
              "clips": [ { "title": "Hello", "style": "title", "width": 2000, "at": [0, 1], "position": [1200, 0], "anchor": "top-left" } ] }
            """#)
        let box = try #require(plan.clips[0].box)

        // When
        let right = (1200 + box.size.width).rounded(.up)

        // Then
        #expect(box.position == .value(Point(x: 1200, y: 0)))
        #expect(plan.format.size == Size(width: (right / 2).rounded(.up) * 2, height: 800))
    }

    @Test("a parented child is measured through its parent's geometry, and stays where it is in its parent's space")
    func measuresParentedChild() throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "id": "page", "media": "/abs/page.png", "duration": 1, "crop": [100, 100, 400, 300],
              "connected": [ { "shape": "fill", "parent": "page", "area": [50, 50, 100, 100] } ] } ] }
            """#)

        // Then
        #expect(plan.format.size == Size(width: 450, height: 350))
        #expect(plan.storyline[0].appearance.box?.position == .value(Point(x: 50, y: 50)))
        #expect(plan.clips[0].area?.firstValue.rectangle == Rectangle(x: 50, y: 50, width: 100, height: 100))
    }

    @Test(
        "the margin is added round the content in each of its forms, which moves the content by its left and top",
        arguments: [
            ("10", Size(width: 320, height: 220), Point(x: 10, y: 10)),
            ("[10, 20]", Size(width: 340, height: 220), Point(x: 20, y: 10)),
            ("[2, 4, 6, 8]", Size(width: 312, height: 208), Point(x: 8, y: 2))
        ]
    )
    func addsMargin(
        margin: String,
        size: Size,
        position: Point
    ) throws {
        // When
        let plan = try plan(
            #"{ "storyline": [ { "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ] }"#,
            margin: margin
        )

        // Then
        #expect(plan.format.size == size)
        #expect(plan.format.margin != nil)
        #expect(plan.storyline[0].appearance.box?.position == .value(position))
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
        let plan = try plan(#"{ "storyline": [ { "media": "/abs/page.png", "duration": 1, \#(crop) } ] }"#, margin: margin)

        // Then
        #expect(plan.format.size == size)
    }

    @Test("every unparented clip and storyline picture is moved by the offset that puts the content's top left at the margin")
    func movesByOffset() throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ],
              "clips": [ { "shape": "fill", "area": [-100.5, -50, 50, 50], "at": [0, 1] },
                         { "media": "/abs/card.png", "width": 100, "height": 100, "at": [0, 1], "position": [0, 0] } ] }
            """#, margin: "4")

        // Then
        #expect(plan.format.size == Size(width: 410, height: 258))
        #expect(plan.storyline[0].appearance.box?.position == .value(Point(x: 105, y: 54)))
        #expect(plan.clips[0].area?.firstValue.rectangle == Rectangle(x: 4.5, y: 4, width: 50, height: 50))
        #expect(plan.clips[1].position == .value(Point(x: 105, y: 54)))
        #expect(plan.clips[1].box?.position == .value(Point(x: 55, y: 4)))
    }

    @Test("a solid fills the measured frame and is not measured")
    func fillsMeasuredFrameWithSolid() throws {
        // Given
        let plan = try plan(##"""
            { "storyline": [ { "solid": "#FF0000", "duration": 1 }, { "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ] }
            """##, margin: "10")

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: PlaceholderHasher())

        // Then
        #expect(plan.format.size == Size(width: 320, height: 220))
        #expect(plan.storyline[0].appearance.box == nil)
        #expect(resolved.storyline[0].box == ResolvedBox(
            size: Size(width: 320, height: 220),
            position: [Keyframe(at: 0, value: Point(x: 0, y: 0))],
            anchor: Point(x: 160, y: 110)
        ))
    }

    @Test("a solid's transform is the identity, so its children are drawn where they were measured, moved by the offset")
    func drawsSolidChildWhereMeasured() throws {
        // Given
        let plan = try plan(##"""
            { "storyline": [ { "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] },
              { "id": "back", "solid": "#FF0000", "duration": 1,
                "connected": [ { "shape": "fill", "parent": "back", "area": [-100, -50, 50, 50] } ] } ] }
            """##, margin: "4")

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: PlaceholderHasher())
        let space = ParentEvaluator(sequence: resolved).space(of: resolved.clips[0], at: 0)

        // Then
        #expect(plan.format.size == Size(width: 408, height: 258))
        #expect(plan.storyline[0].appearance.box?.position == .value(Point(x: 104, y: 54)))
        #expect(plan.clips[0].area?.firstValue.rectangle == Rectangle(x: 4, y: 4, width: 50, height: 50))
        #expect(space.transform == .identity)
    }

    @Test("a solid's children are in the measuring space, which has no edges, so an area outside the first box grows the frame")
    func measuresSolidChildOutsideFirstBox() throws {
        // When
        let plan = try plan(##"""
            { "storyline": [ { "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] },
              { "id": "back", "solid": "#FF0000", "duration": 1,
                "connected": [ { "shape": "fill", "parent": "back", "area": [400, 0, 50, 50] } ] } ] }
            """##)

        // Then
        #expect(plan.format.size == Size(width: 450, height: 200))
        #expect(plan.clips[0].area?.firstValue.rectangle == Rectangle(x: 400, y: 0, width: 50, height: 50))
    }

    @Test("theme lengths take the length scale of the first storyline picture's box")
    func scalesByFirstStorylinePicture() throws {
        // When
        let plan = try plan(##"""
            { "storyline": [ { "solid": "#FF0000", "duration": 1 }, { "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 603, 400] } ],
              "clips": [ { "shape": "box", "area": [0, 0, 100, 100], "at": [0, 1] } ] }
            """##)

        // Then
        let scale = MergedTheme.base.lengthScale(at: 603)
        #expect(plan.clips[0].appearance.shape == .box(
            width: MergedTheme.base.boxWidth * scale,
            radius: MergedTheme.base.boxRadius * scale,
            color: MergedTheme.base.shapeColor(of: .box)
        ))
    }

    @Test(
        "a placement and a title without a width stop, since both would depend on the frame being measured",
        arguments: [
            (#"{ "title": "Hi", "style": "title", "width": 300, "placement": "top", "at": [0, 1] }"#, ResolveError.placementUnderContentFit(place: Place.root.appending(key: "clips").appending(index: 0), kind: .clip(.title))),
            (#"{ "media": "/abs/card.png", "placement": "center", "at": [0, 1] }"#, ResolveError.placementUnderContentFit(place: Place.root.appending(key: "clips").appending(index: 0), kind: .clip(.media(.image)))),
            (#"{ "title": "Hi", "style": "title", "position": [0, 0], "at": [0, 1] }"#, ResolveError.titleWidthUnderContentFit(place: Place.root.appending(key: "clips").appending(index: 0), kind: .clip(.title)))
        ]
    )
    func refusesWhatNamesFrame(
        clip: String,
        expected: ResolveError
    ) throws {
        // Given
        let document = #"{ "storyline": [ { "media": "/abs/page.png", "duration": 1 } ], "clips": [ \#(clip) ] }"#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error == expected)
    }

    @Test("a storyline of solids leaves nothing to measure and no length scale, so it stops")
    func refusesNothingMeasured() throws {
        // Given
        let document = ##"""
            { "storyline": [ { "solid": "#FF0000", "duration": 1 } ],
              "clips": [ { "shape": "fill", "area": [0, 0, 100, 100], "at": [0, 1] } ] }
            """##

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(document) }
        #expect(error?.description == #"format.size (sequence): every storyline clip is a solid, so a frame measured from the content has nothing to measure and no length scale, and the format needs "size""#)
    }

    @Test("a compound clip whose sequence fits its content has the measured size as its own frame size")
    func takesMeasuredSizeOfCompoundClip() throws {
        // When
        let plan = try plan(#"""
            { "storyline": [ { "media": { "kind": "sequence", "format": { "size": { "fit": "content", "margin": 5 } },
              "storyline": [ { "media": "/abs/page.png", "duration": 1, "crop": [0, 0, 300, 200] } ] } } ] }
            """#)

        // Then
        #expect(plan.format.size == Size(width: 310, height: 210))
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
