//
//  DisplayListReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("DisplayListReader Tests")
struct DisplayListReaderTests {
    // MARK: - Property
    private let sut = DisplayListReader()
    private let writer = DisplayListWriter()

    private static let hash = String(repeating: "a", count: 64)
    private static let video = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/run.mp4", sha256: hash)),
        frameTimes: [0, 0.033367, 0.066733]
    )
    private static let still = PinnedMedia(source: .file(PinnedFile(path: "/abs/page.png", sha256: hash)))
    private static let imageSequence = PinnedMedia(
        source: .imageSequence([
            PinnedFile(path: "/abs/frames/0001.png", sha256: hash),
            PinnedFile(path: "/abs/frames/0002.png", sha256: hash)
        ]),
        frameTimes: [0, 0.5]
    )
    private static let origin = ItemOrigin(place: "storyline[1]#intro", id: "intro", kind: "video")
    private static let rotation = AffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
    // One mask of each geometry form and mode, feathered, inverted and carried by a transform.
    private static let masks = [
        ItemMask(
            geometry: .rect(Rectangle(x: 0, y: 0, width: 1080, height: 1500), radius: 24),
            transform: rotation,
            feather: 0,
            isInverted: false,
            mode: .add
        ),
        ItemMask(
            geometry: .ellipse(Rectangle(x: 100, y: 200, width: 300, height: 150)),
            transform: AffineTransform(a: 1.5, b: 0, c: 0, d: 1.5, tx: -20, ty: 40.5),
            feather: 12.5,
            isInverted: true,
            mode: .subtract
        ),
        ItemMask(
            geometry: .polyline([Point(x: 0, y: 0), Point(x: 540, y: 0), Point(x: 270, y: 960)], isClosed: true),
            transform: .identity,
            feather: 3,
            isInverted: false,
            mode: .intersect
        )
    ]

    // Items that between them hold every kind and every optional member, set and null.
    private static let items: [DisplayItem] = [
        DisplayItem(
            transform: rotation,
            opacity: 0.5,
            blend: "multiply",
            mask: masks,
            reveal: Rectangle(x: 0, y: 0, width: 540, height: 1920),
            content: .picture(PictureItem(
                source: .media(MediaFrame(media: video, index: 2)),
                rectangle: Rectangle(x: 45, y: 97.5, width: 990, height: 1760),
                destination: Rectangle(x: 10, y: 20, width: 495, height: 880),
                filter: [FilterEntry(operations: [.exposure(ev: 0.5), .blur(radius: 2)], mix: 0.5)],
                matte: PictureMatte(frame: MediaFrame(media: still, index: 0), progress: 0.25, softness: 0.1, isInverted: true),
                radius: 12,
                border: MediaBorder(width: 4, color: Color(written: "#FFFFFF")),
                shadow: DropShadow(radius: 8, offset: Point(x: 0, y: 6), color: Color(written: "#00000080"))
            )),
            origin: origin
        ),
        DisplayItem(content: .picture(PictureItem(
            source: .media(MediaFrame(media: imageSequence, index: 1)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 1080, height: 1920)
        ))),
        DisplayItem(
            content: .path(PathItem(
                geometry: .rect(Rectangle(x: 0, y: 0, width: 1080, height: 1920), radius: 16),
                fill: Color(written: "#00000099"),
                stroke: nil,
                shadow: DropShadow(radius: 4, offset: Point(x: 2, y: 3), color: Color(written: "#00000080"))
            )),
            origin: ItemOrigin(place: "clips[3]", id: nil, kind: "shape")
        ),
        DisplayItem(content: .path(PathItem(
            filling: Rectangle(x: 0, y: 1500, width: 1080, height: 420),
            color: Color(written: "#000000")
        ))),
        DisplayItem(
            transform: AffineTransform(a: 1.2, b: 0, c: 0, d: 1.2, tx: -54, ty: -96),
            content: .path(PathItem(
                geometry: .ellipse(Rectangle(x: 150, y: 150, width: 100, height: 50)),
                fill: nil,
                stroke: PathStroke(
                    width: 6,
                    color: Color(written: "#FF3B30"),
                    join: .miter,
                    cap: .square,
                    start: .none,
                    end: .none
                ),
                trim: Trim(start: 0.125, end: 0.625)
            ))
        ),
        DisplayItem(content: .path(PathItem(
            geometry: .polyline([Point(x: 240, y: 175), Point(x: 300, y: 175)], isClosed: false),
            fill: nil,
            stroke: PathStroke(width: 6, color: Color(written: "#FF3B30"), join: .round, cap: .round, start: .none, end: .arrow),
            trim: Trim(start: 0, end: 0.6)
        ))),
        DisplayItem(
            transform: AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 75.4, ty: 1709.8),
            opacity: 0.75,
            content: .glyphs(GlyphsItem(
                size: Size(width: 120, height: 48),
                runs: [ResolvedGlyphRun(
                    font: PinnedFile(path: "/abs/Inter.ttf", sha256: hash),
                    face: "Inter-Bold",
                    size: 32,
                    color: Color(written: "#FFFFFF"),
                    stroke: TextStroke(width: 2, color: Color(written: "#000000")),
                    glyphs: [PositionedGlyph(id: 43, x: 12, y: 36), PositionedGlyph(id: 76, x: 34.5, y: 36)]
                )],
                background: GlyphBackground(rectangle: Rectangle(x: 0, y: 0, width: 120, height: 48), radius: 6, color: Color(written: "#111111CC"))
            )),
            origin: ItemOrigin(place: "clips[0]", id: nil, kind: "title")
        ),
        DisplayItem(content: .glyphs(GlyphsItem(size: Size(width: 10, height: 10), runs: [], background: nil))),
        DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.saturation(amount: 0)])]))),
        DisplayItem(content: .path(PathItem(
            geometry: .polyline([Point(x: 0, y: 0), Point(x: 40, y: 0), Point(x: 20, y: 30)], isClosed: true),
            fill: Color(written: "#3366CC"),
            stroke: PathStroke(width: 2.5, color: Color(written: "#FFFFFF80"), join: .bevel, cap: .butt, start: .arrow, end: .arrow),
            trim: Trim(start: 0.75, end: 0.25),
            shadow: DropShadow(radius: 0, offset: Point(x: 0, y: 0), color: Color(written: "#000000"))
        )))
    ]

    private static let operations: [ResolvedFilterOperation] = [
        .exposure(ev: -0.5),
        .contrast(amount: 1.2),
        .saturation(amount: 0.8),
        .temperature(kelvin: 5600),
        .hue(degrees: 15),
        .sepia(amount: 0.3),
        .levels(input: [0.05, 0.95], output: [0, 1]),
        .lut(file: PinnedFile(path: "/abs/film.cube", sha256: hash), amount: 0.5),
        .blur(radius: 4),
        .sharpen(amount: 0.4, radius: 1.5),
        .bloom(amount: 0.5, radius: 4, color: Color(written: "#FFEEDD")),
        .bloom(amount: 0.5, radius: 4, color: nil),
        .vignette(amount: 0.6, radius: 0.8),
        .pixelate(size: 12),
        .grain(amount: 0.2, size: 1.5)
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("every kind of display item reads back to the item it was written from", arguments: items.indices)
    func readsWrittenItem(index: Int) throws {
        // Given
        let list = list(items: [Self.items[index]])

        // When
        let read = try sut.read(writer.write(list))

        // Then
        #expect(read == list)
    }

    @Test("every filter operation reads back, a grain with the list's seed", arguments: operations.indices)
    func readsWrittenOperation(index: Int) throws {
        // Given
        let filter = [Self.operations[index], .grain(amount: 0.1, size: 1)]
        let list = list(
            seed: 7,
            items: [
                DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: filter)]))),
                DisplayItem(content: .picture(PictureItem(
                    source: .media(MediaFrame(media: Self.still, index: 0)),
                    rectangle: nil,
                    destination: Rectangle(x: 0, y: 0, width: 10, height: 10),
                    filter: [FilterEntry(operations: filter)]
                )))
            ]
        )

        // When
        let read = try sut.read(writer.write(list))

        // Then
        #expect(read == list)
    }

    @Test("every blend mode reads back", arguments: VocabularyTable.blendModes)
    func readsWrittenBlend(blend: String) throws {
        // Given
        let list = list(items: [
            DisplayItem(blend: blend, content: .path(PathItem(filling: Rectangle(x: 0, y: 0, width: 1, height: 1), color: Color(written: "#FFFFFF"))))
        ])

        // When
        let read = try sut.read(writer.write(list))

        // Then
        #expect(read == list)
    }

    @Test("a nested list reads back with the seed of the list holding it, from a grain written only inside it")
    func readsNestedList() throws {
        // Given
        let inner = list(
            size: Size(width: 400, height: 300),
            seed: 12,
            items: [DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.grain(amount: 0.3, size: 2)])])))]
        )
        let nested = list(
            size: Size(width: 1080, height: 1500),
            seed: 12,
            items: [
                Self.items[0],
                DisplayItem(
                    content: .picture(PictureItem(
                        source: .displayList(inner),
                        rectangle: Rectangle(x: 0, y: 0, width: 400, height: 300),
                        destination: Rectangle(x: 100, y: 100, width: 800, height: 600)
                    )),
                    origin: ItemOrigin(place: "storyline[0].media.clips[0]", id: nil, kind: "sequence")
                )
            ]
        )
        let list = list(
            seed: 12,
            items: [DisplayItem(
                mask: [Self.masks[0]],
                content: .picture(PictureItem(
                    source: .displayList(nested),
                    rectangle: Rectangle(x: 0, y: 0, width: 1080, height: 1500),
                    destination: Rectangle(x: 0, y: 0, width: 1080, height: 1500)
                ))
            )]
        )

        // When
        let read = try sut.read(writer.write(list))

        // Then
        #expect(read == list)
    }

    @Test("a track matte reads back with its source the size of the list holding its item, from a grain only inside it")
    func readsTrackMatte() throws {
        // Given
        let source = list(
            seed: 7,
            items: [Self.items[5], DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.grain(amount: 0.3, size: 2)])])))]
        )
        let list = list(
            seed: 7,
            items: [
                DisplayItem(trackMatte: ItemTrackMatte(source: source, mode: .luma, isInverted: true), content: Self.items[2].content),
                DisplayItem(trackMatte: ItemTrackMatte(source: list(seed: 7, items: []), mode: .alpha, isInverted: false), content: Self.items[2].content)
            ]
        )

        // When
        let read = try sut.read(writer.write(list))

        // Then
        #expect(read == list)
    }

    @Test("a track matte is written as {source: {list}, mode, invert} after the mask, and an item without one as null")
    func writesTrackMatteMembers() throws {
        // Given
        let source = list(items: [])
        let list = list(items: [
            DisplayItem(trackMatte: ItemTrackMatte(source: source, mode: .alpha, isInverted: false), content: Self.items[2].content),
            Self.items[2]
        ])

        // When
        let items = writer.document(list).objectValue?["items"]?.arrayValue?.compactMap(\.objectValue)

        // Then
        #expect(items?.first?.keys.prefix(8) == ["item", "origin", "transform", "opacity", "blend", "mask", "trackMatte", "reveal"])
        #expect(items?.first?["trackMatte"] == (try Fixture.json(#"""
            { "source": { "list": { "size": [1080, 1920], "background": "#000000FF", "items": [] } }, "mode": "alpha", "invert": false }
            """#)))
        #expect(items?.last?["trackMatte"] == .null)
    }

    @Test("a track matte's source of another size than the list holding its item stops, naming both sizes")
    func refusesTrackMatteSize() throws {
        // Given
        let source = list(size: Size(width: 540, height: 960), items: [])
        let list = list(items: [
            DisplayItem(trackMatte: ItemTrackMatte(source: source, mode: .alpha, isInverted: false), content: Self.items[2].content)
        ])

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(writer.write(list)) }

        // Then
        #expect(error?.description == "items[0].trackMatte.source (path): the track matte's source is 540 by 960, and a track matte's source is the size of the list that holds its item, 1080 by 1920")
    }

    @Test("a list with no grain reads with seed 0, since only a grain carries the seed")
    func readsSeedZeroWithoutGrain() throws {
        // Given
        let list = list(seed: 9, items: [Self.items[2]])

        // When
        let read = try sut.read(writer.write(list))

        // Then
        #expect(read.seed == 0)
        #expect(read.items == list.items)
    }

    @Test("a picture that shows its whole source and an item no clip drew are written with null")
    func writesNullCoverRectangleAndOrigin() throws {
        // Given
        let list = list(items: [Self.items[1]])

        // When
        let item = writer.document(list).objectValue?["items"]?.arrayValue?.first?.objectValue

        // Then
        #expect(item?["rect"] == .null)
        #expect(item?["origin"] == .null)
    }

    @Test("an item without masks writes its mask as null, and each mask holds its geometry in the path's form")
    func writesMaskMembers() throws {
        // Given
        let list = list(items: [Self.items[0], Self.items[1]])

        // When
        let items = writer.document(list).objectValue?["items"]?.arrayValue
        let masks = items?.first?.objectValue?["mask"]?.arrayValue

        // Then
        #expect(items?.last?.objectValue?["mask"] == .null)
        #expect(masks?.count == 3)
        #expect(masks?.first?.objectValue?.keys == ["geometry", "transform", "feather", "invert", "mode"])
        #expect(masks?.first == (try Fixture.json(#"""
            { "geometry": { "rect": { "rect": [0, 0, 1080, 1500], "radius": 24 } }, "transform": [0, 1, -1, 0, 1080, 0],
              "feather": 0, "invert": false, "mode": "add" }
            """#)))
    }

    @Test(
        "a mask list that is empty, or a mask that is not a closed polyline through three points, has a missing key, a negative feather or an unknown mode stops",
        arguments: [
            ("[]", "items[0].mask (path): a mask list holds at least one mask, and an item without one has null"),
            (
                #"[{ "geometry": { "polyline": { "points": [[0, 0], [4, 0], [2, 4]], "closed": false } }, "transform": [1, 0, 0, 1, 0, 0], "feather": 0, "invert": false, "mode": "add" }]"#,
                "items[0].mask[0].geometry (path): a path mask is a closed polyline through at least three points"
            ),
            (
                #"[{ "geometry": { "polyline": { "points": [[0, 0], [4, 0]], "closed": true } }, "transform": [1, 0, 0, 1, 0, 0], "feather": 0, "invert": false, "mode": "add" }]"#,
                "items[0].mask[0].geometry (path): a path mask is a closed polyline through at least three points"
            ),
            (
                #"[{ "geometry": { "ellipse": { "rect": [0, 0, 4, 4] } }, "transform": [1, 0, 0, 1, 0, 0], "feather": 0, "invert": false }]"#,
                #"items[0].mask[0] (path): missing key "mode""#
            ),
            (
                #"[{ "geometry": { "ellipse": { "rect": [0, 0, 4, 4] } }, "transform": [1, 0, 0, 1, 0, 0], "feather": -2, "invert": false, "mode": "add" }]"#,
                "items[0].mask[0].feather (path): a feather is 0 or more, found -2"
            ),
            (
                #"[{ "geometry": { "ellipse": { "rect": [0, 0, 4, 4] } }, "transform": [1, 0, 0, 1, 0, 0], "feather": 0, "invert": false, "mode": "multiply" }]"#,
                #"items[0].mask[0].mode (path): unknown value "multiply". Allowed: add, subtract, intersect"#
            ),
            (
                #"[{ "geometry": { "ellipse": { "rect": [0, 0, 4, 4] } }, "transform": [1, 0, 0, 1, 0, 0], "feather": 0, "invert": false, "mode": "add", "expansion": 2 }]"#,
                #"items[0].mask[0] (path): unknown key "expansion". Allowed: geometry, transform, feather, invert, mode"#
            )
        ]
    )
    func refusesUnreadableMask(
        written: String,
        message: String
    ) throws {
        // Given
        let text = #"""
            { "displayList": "\#(FramesVersion.current)", "size": [10, 10], "background": "#000000FF", "items": [
              { "item": "path", "origin": null, "transform": [1, 0, 0, 1, 0, 0], "opacity": 1, "blend": "normal",
                "mask": \#(written), "trackMatte": null, "reveal": null, "geometry": { "rect": { "rect": [0, 0, 1, 1], "radius": 0 } },
                "fill": "#FFFFFFFF", "stroke": null, "trim": [0, 1], "shadow": null } ] }
            """#

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a grain with a seed other than the first grain's stops, naming its place")
    func refusesDifferentSeed() throws {
        // Given
        let inner = list(
            seed: 4,
            items: [DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.grain(amount: 0.3, size: 2)])])))]
        )
        let list = list(
            seed: 3,
            items: [
                DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.grain(amount: 0.3, size: 2)])]))),
                DisplayItem(content: .picture(PictureItem(
                    source: .displayList(inner),
                    rectangle: nil,
                    destination: Rectangle(x: 0, y: 0, width: 1080, height: 1920)
                )))
            ]
        )

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(writer.write(list)) }

        // Then
        #expect(error?.description == """
            items[1].source.list.items[0].filter[0].ops[0].seed (adjust): seed 4 differs from 3, the seed of the first grain \
            in the list, and every grain of an output frame takes that frame's number
            """)
    }

    @Test(
        "a display list from a later minor version or another major version is refused, naming both versions",
        arguments: ["1.1.0", "2.0.0", "0.9.0"]
    )
    func refusesOtherVersion(version: String) throws {
        // Given
        let text = replacingFirst(#""displayList": "1.0.0""#, with: #""displayList": "\#(version)""#, in: written())

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"""
            displayList (display list): the display list was written by frames "\#(version)", and frames 1.0.0 reads \#
            only one written by frames 1.0 up to 1.0
            """#)
    }

    @Test(
        "a member that is missing, of another type, or never written there stops, naming its place",
        arguments: [
            (#""displayList": "1.0.0","#, "", #"top level (display list): missing key "displayList""#),
            (#""trim": [0.125, 0.625]"#, #""trimmed": [0.125, 0.625]"#, #"items[4] (path): unknown key "trimmed". Allowed: item, origin, transform, opacity, blend, mask, trackMatte, reveal, geometry, fill, stroke, trim, shadow"#),
            (#""rect": [0, 0, 1080, 1920],"#, "", #"items[2].geometry.rect (path): missing key "rect""#),
            (#""blend": "multiply""#, #""blend": "add""#, #"items[0].blend (picture): unknown value "add". Allowed: normal, multiply, screen, overlay, darken, lighten, color-dodge, color-burn, hard-light, soft-light, difference, exclusion, plus-lighter, hue, saturation, color, luminosity"#),
            (#""item": "path""#, #""item": "line""#, #"items[2].item (display item): unknown value "line". Allowed: picture, path, glyphs, adjust"#),
            (#""frame": 2"#, #""frame": 3"#, "items[0].source.frame (picture): frame 3 is not a frame of the media, whose frames are 0 to 2"),
            (#""opacity": 0.75"#, #""opacity": "0.75""#, #"items[6].opacity (glyphs): expected a number, found "0.75""#)
        ]
    )
    func refusesUnreadableMember(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let text = replacingFirst(written, with: replacement, in: self.written())

        // When
        let error = #expect(throws: (any Error).self) { try sut.read(text) }

        // Then
        #expect((error as? CustomStringConvertible)?.description == message)
    }

    @Test("a path's fill, stroke and shadow are written null where it has none, and its trim as [a, b]")
    func writesPathMembers() throws {
        // Given
        let list = list(items: [Self.items[5]])

        // When
        let item = try #require(writer.document(list).objectValue?["items"]?.arrayValue?.first?.objectValue)

        // Then
        #expect(item.keys == [
            "item", "origin", "transform", "opacity", "blend", "mask", "trackMatte", "reveal", "geometry", "fill", "stroke",
            "trim", "shadow"
        ])
        #expect(item["item"] == .string("path"))
        #expect(item["fill"] == .null)
        #expect(item["shadow"] == .null)
        #expect(item["trim"] == .array([.number(0), .number(0.6)]))
        #expect(item["stroke"]?.objectValue?.keys == ["width", "color", "join", "cap", "start", "end", "dash", "dashOffset"])
        #expect(item["geometry"] == (try Fixture.json(#"{ "polyline": { "points": [[240, 175], [300, 175]], "closed": false } }"#)))
    }

    @Test(
        "a path whose geometry, stroke literal or trim is not of the JSON form stops, naming its place",
        arguments: [
            (
                #"{ "polyline": { "points": [[1, 2]], "closed": false } }"#,
                "geometry",
                "items[0].geometry.polyline.points (path): a polyline runs through at least two points, found 1"
            ),
            (
                #"{ "rect": { "rect": [0, 0, 1, 1], "radius": 0 }, "ellipse": { "rect": [0, 0, 1, 1] } }"#,
                "geometry",
                #"items[0].geometry (path): takes only one of "rect", "ellipse""#
            ),
            ("{}", "geometry", "items[0].geometry (path): needs one of rect, ellipse, polyline"),
            (
                #"{ "spline": { "points": [[0, 0], [1, 1]] } }"#,
                "geometry",
                #"items[0].geometry (path): unknown key "spline". Allowed: rect, ellipse, polyline"#
            ),
            (
                #"{ "ellipse": { "rect": [0, 0, 1, 1], "radius": 2 } }"#,
                "geometry",
                #"items[0].geometry.ellipse (path): unknown key "radius". Allowed: rect"#
            ),
            (
                ##"{ "width": 2, "color": "#FFFFFFFF", "join": "sharp", "cap": "butt", "start": "none", "end": "none" }"##,
                "stroke",
                #"items[0].stroke.join (path): unknown value "sharp". Allowed: miter, round, bevel"#
            ),
            (
                ##"{ "width": 2, "color": "#FFFFFFFF", "join": "round", "cap": "flat", "start": "none", "end": "none" }"##,
                "stroke",
                #"items[0].stroke.cap (path): unknown value "flat". Allowed: butt, round, square"#
            ),
            (
                ##"{ "width": 2, "color": "#FFFFFFFF", "join": "round", "cap": "butt", "start": "none", "end": "dot" }"##,
                "stroke",
                #"items[0].stroke.end (path): unknown value "dot". Allowed: none, arrow"#
            ),
            ("[0, 1.5]", "trim", "items[0].trim[1] (path): a trim runs from 0 to 1, found 1.5"),
            ("[-0.25, 1]", "trim", "items[0].trim[0] (path): a trim runs from 0 to 1, found -0.25"),
            ("[0]", "trim", "items[0].trim (path): expected a list of 2 numbers, found a list of 1")
        ]
    )
    func refusesUnreadablePath(
        written: String,
        member: String,
        message: String
    ) throws {
        // Given
        var members = [
            "geometry": #"{ "rect": { "rect": [0, 0, 1, 1], "radius": 0 } }"#,
            "stroke": "null",
            "trim": "[0, 1]"
        ]
        members[member] = written
        let text = #"""
            { "displayList": "\#(FramesVersion.current)", "size": [10, 10], "background": "#000000FF", "items": [
              { "item": "path", "origin": null, "transform": [1, 0, 0, 1, 0, 0], "opacity": 1, "blend": "normal",
                "mask": null, "trackMatte": null, "reveal": null, "geometry": \#(members["geometry"] ?? ""),
                "fill": "#FFFFFFFF",
                "stroke": \#(members["stroke"] ?? ""), "trim": \#(members["trim"] ?? ""), "shadow": null } ] }
            """#

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    // MARK: - Private
    private func list(
        size: Size = Size(width: 1080, height: 1920),
        seed: Int = 0,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: size, background: Color(written: "#000000"), seed: seed, items: items)
    }

    private func written() -> String {
        writer.write(list(items: Self.items))
    }

    private func replacingFirst(
        _ target: String,
        with replacement: String,
        in text: String
    ) -> String {
        guard let range = text.range(of: target) else {
            Issue.record("\(target) is not in the text")
            return text
        }

        return text.replacingCharacters(in: range, with: replacement)
    }
}
