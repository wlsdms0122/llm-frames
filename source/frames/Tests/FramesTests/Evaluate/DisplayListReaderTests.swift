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
    private static let page = PinnedMedia(source: .page(PinnedFile(path: "/abs/deck.pdf", sha256: hash), page: 3))
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
                matte: PictureMatte(
                    frame: MediaFrame(media: still, index: 0, reading: .analysis(colorSpace: nil)),
                    progress: 0.25,
                    softness: 0.1,
                    isInverted: true
                ),
                radius: 12,
                border: MediaBorder(width: 4, color: Color(written: "#FFFFFF"), align: .outside),
                shadow: DropShadow(radius: 8, offset: Point(x: 0, y: 6), color: Color(written: "color(srgb 0 0 0 / 0.5019607843137255)"))
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
                fill: .color(Color(written: "color(srgb 0 0 0 / 0.6)")),
                stroke: nil,
                shadow: DropShadow(radius: 4, offset: Point(x: 2, y: 3), color: Color(written: "color(srgb 0 0 0 / 0.5019607843137255)"))
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
                    paint: .color(Color(written: "#FF3B30")),
                    join: .miter,
                    cap: .square,
                    start: .none,
                    end: .none
                ),
                trim: Trim(start: 0.125, end: 0.625)
            ))
        ),
        DisplayItem(content: .path(PathItem(
            geometry: .path(
                [
                    PathVertex(vertex: Point(x: 240, y: 175), inTangent: Point(x: 0, y: 0), outTangent: Point(x: 20, y: -30)),
                    PathVertex(vertex: Point(x: 300, y: 175), inTangent: Point(x: -10, y: -15.5), outTangent: Point(x: 0, y: 0))
                ],
                isClosed: false
            ),
            fill: nil,
            stroke: PathStroke(width: 6, paint: .color(Color(written: "#FF3B30")), join: .round, cap: .round, start: .none, end: .arrow),
            trim: Trim(start: 0, end: 0.6)
        ))),
        DisplayItem(
            transform: AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 75.4, ty: 1709.8),
            opacity: 0.75,
            content: .glyphs(GlyphsItem(
                size: Size(width: 120, height: 48),
                runs: [DrawnGlyphRun(
                    font: PinnedFile(path: "/abs/Inter.ttf", sha256: hash),
                    face: "Inter-Bold",
                    size: 32,
                    color: Color(written: "#FFFFFF"),
                    stroke: TextStroke(width: 2, color: Color(written: "#000000")),
                    highlight: DrawnHighlight(
                        rects: [Rectangle(x: 10, y: 4, width: 50, height: 40)],
                        radius: 4,
                        color: Color(written: "#F2B705"),
                        bands: [12...30]
                    ),
                    underline: DrawnUnderline(
                        rects: [Rectangle(x: 12, y: 40, width: 46, height: 2)],
                        color: Color(written: "#FFFFFF"),
                        bands: nil
                    ),
                    glyphs: [PositionedGlyph(id: 43, x: 12, y: 36), PositionedGlyph(id: 76, x: 34.5, y: 36)]
                )],
                background: GlyphBackground(rectangle: Rectangle(x: 0, y: 0, width: 120, height: 48), radius: 6, color: Color(written: "color(srgb 0.06666666666666667 0.06666666666666667 0.06666666666666667 / 0.8)"))
            )),
            origin: ItemOrigin(place: "clips[0]", id: nil, kind: "title")
        ),
        DisplayItem(content: .glyphs(GlyphsItem(size: Size(width: 10, height: 10), runs: [], background: nil))),
        DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.saturation(amount: 0)])]))),
        DisplayItem(content: .path(PathItem(
            geometry: .polyline([Point(x: 0, y: 0), Point(x: 40, y: 0), Point(x: 20, y: 30)], isClosed: true),
            fill: .color(Color(written: "#3366CC")),
            stroke: PathStroke(width: 2.5, paint: .color(Color(written: "color(srgb 1 1 1 / 0.5019607843137255)")), join: .bevel, cap: .butt, start: .arrow, end: .arrow),
            trim: Trim(start: 0.75, end: 0.25),
            shadow: DropShadow(radius: 0, offset: Point(x: 0, y: 0), color: Color(written: "#000000"))
        ))),
        DisplayItem(content: .path(PathItem(
            geometry: .rect(Rectangle(x: 10, y: 20, width: 200, height: 100), radius: 0),
            fill: .gradient(Gradient(
                shape: .linear(from: Point(x: 10, y: 20), to: Point(x: 210, y: 20)),
                stops: [GradientStop(offset: 0, color: Color(written: "color(srgb 1 0 0 / 0)")), GradientStop(offset: 1, color: Color(written: "#0000FF"))]
            )),
            stroke: PathStroke(
                width: 4,
                paint: .gradient(Gradient(
                    shape: .radial(center: Point(x: 110, y: 70), radius: 111.8),
                    stops: [
                        GradientStop(offset: 0, color: Color(written: "#FFFFFF")),
                        GradientStop(offset: 0.5, color: Color(written: "#FFFFFF")),
                        GradientStop(offset: 0.5, color: Color(written: "color(srgb 0 0 0 / 0.5019607843137255)"))
                    ]
                )),
                join: .round,
                cap: .butt,
                start: .none,
                end: .arrow
            )
        ))),
        DisplayItem(content: .glyphs(GlyphsItem(
            size: Size(width: 10, height: 10),
            runs: [],
            unit: UnitDrawing(layer: .strokes, index: 3, box: Rectangle(x: 2, y: 1, width: 6, height: 8)),
            extent: Rectangle(x: 3, y: 2, width: 4, height: 6),
            background: nil
        )), origin: ItemOrigin(place: "clips[1]", id: "lower", kind: "title")),
        DisplayItem(content: .picture(PictureItem(
            source: .displayList(DisplayList(size: Size(width: 120, height: 80), background: .transparent, seed: 0, items: [])),
            rectangle: Rectangle(x: -10, y: -10, width: 100, height: 60),
            destination: Rectangle(x: 0, y: 0, width: 100, height: 60),
            cornerPin: Quad(
                topLeft: Point(x: 812, y: 304),
                topRight: Point(x: 1131, y: 352),
                bottomRight: Point(x: 1102, y: 918),
                bottomLeft: Point(x: 779, y: 861)
            )
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
        .displace(file: PinnedFile(path: "/abs/ripple.png", sha256: hash), amount: 16, offset: Point(x: -8, y: 2.5)),
        .pixelate(size: 12),
        .grain(amount: 0.2, size: 1.5)
    ]

    // `items` with a picture of a nested list under a track matte, at 13, a grain, at 14, a LUT, a bloom with a colour,
    // levels and a displace, at 15, and a page cut by a matte of itself, at 16, so a sample list holds every field of the
    // Moves columns.
    private static let sampleItems = items + [
        DisplayItem(
            trackMatte: ItemTrackMatte(
                source: DisplayList(size: Size(width: 1080, height: 1920), background: Color(written: "#000000"), seed: 0, items: [items[2]]),
                mode: .luma,
                isInverted: false
            ),
            content: .picture(PictureItem(
                source: .displayList(DisplayList(size: Size(width: 400, height: 300), background: Color(written: "#000000"), seed: 0, items: [items[4]])),
                rectangle: nil,
                destination: Rectangle(x: 100, y: 100, width: 400, height: 300)
            ))
        ),
        DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.grain(amount: 0.2, size: 1.5)])]))),
        DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [
            .lut(file: PinnedFile(path: "/abs/film.cube", sha256: hash), amount: 0.5),
            .bloom(amount: 0.5, radius: 4, color: Color(written: "#FFEEDD")),
            .levels(input: [0.05, 0.95], output: [0, 1]),
            .displace(file: PinnedFile(path: "/abs/ripple.png", sha256: hash), amount: 16, offset: Point(x: -8, y: 2.5))
        ])]))),
        DisplayItem(content: .picture(PictureItem(
            source: .media(MediaFrame(media: page, index: 0)),
            rectangle: Rectangle(x: 0, y: 0, width: 100, height: 50),
            destination: Rectangle(x: 0, y: 0, width: 400, height: 200),
            matte: PictureMatte(
                frame: MediaFrame(media: page, index: 0, reading: .analysis(colorSpace: nil)),
                progress: 0.5,
                softness: 0.1,
                isInverted: false
            )
        )))
    ]

    // A path in the written list with samples, what is put there or nil to remove it, and the message of the stop.
    private static let samplesForms: [([String], JSONValue?, String)] = [
        (["items"], JSONValue.array([]), #"top level (display list): takes only one of "items", "samples""#),
        (["samples"], nil, "top level (display list): needs one of items, samples"),
        (["samples", "1"], nil, "samples (display list): a list with samples holds at least two sample lists, found 1"),
        (
            ["samples", "0", "13", "source", "list", "samples"],
            JSONValue.array([.array([]), .array([])]),
            "samples[0][13].source.list.samples (display list): only the outermost list of a frame holds samples"
        )
    ]

    // A path in the second sample list, what is written there or nil to remove it, and the place the reading stops at.
    private static let unmovedFields: [([String], String?, String)] = [
        (["1", "0", "blend"], #""screen""#, "samples[1][0].blend (picture)"),
        (["1", "0", "origin", "place"], #""storyline[2]""#, "samples[1][0].origin.place (picture)"),
        (["1", "0", "mask"], "null", "samples[1][0].mask (picture)"),
        (["1", "0", "mask", "1", "invert"], "false", "samples[1][0].mask[1].invert (picture)"),
        (["1", "0", "mask", "2", "mode"], #""add""#, "samples[1][0].mask[2].mode (picture)"),
        (["1", "0", "source", "frame"], "1", "samples[1][0].source.frame (picture)"),
        (["1", "0", "source", "colorSpace"], #""srgb""#, "samples[1][0].source.colorSpace (picture)"),
        (["1", "0", "matte", "softness"], "0.2", "samples[1][0].matte.softness (picture)"),
        (["1", "0", "matte", "invert"], "false", "samples[1][0].matte.invert (picture)"),
        (["1", "0", "filter"], "[]", "samples[1][0].filter (picture)"),
        (["1", "0", "border"], "null", "samples[1][0].border (picture)"),
        (["1", "0", "reveal"], "null", "samples[1][0].reveal (picture)"),
        (["1", "1", "reveal"], "[0, 0, 10, 10]", "samples[1][1].reveal (picture)"),
        (
            ["1", "0", "filter", "0", "ops"],
            #"[{ "op": "blur", "radius": 2 }, { "op": "exposure", "ev": 0.5 }]"#,
            "samples[1][0].filter[0].ops[0].op (picture)"
        ),
        (["1", "4", "stroke", "join"], #""round""#, "samples[1][4].stroke.join (path)"),
        (["1", "4", "stroke", "cap"], #""round""#, "samples[1][4].stroke.cap (path)"),
        (["1", "4", "stroke", "end"], #"{ "shape": "arrow", "scale": 1 }"#, "samples[1][4].stroke.end (path)"),
        (["1", "5", "stroke", "end", "shape"], #""circle""#, "samples[1][5].stroke.end.shape (path)"),
        (["1", "4", "stroke", "dash"], "[2, 2]", "samples[1][4].stroke.dash (path)"),
        (["1", "6", "runs", "0", "file"], #""/abs/Other.ttf""#, "samples[1][6].runs[0].file (glyphs)"),
        (["1", "6", "runs", "0", "face"], #""Inter-Regular""#, "samples[1][6].runs[0].face (glyphs)"),
        (["1", "6", "runs", "0", "size"], "30", "samples[1][6].runs[0].size (glyphs)"),
        (["1", "6", "runs", "0", "glyphs", "1", "0"], "77", "samples[1][6].runs[0].glyphs[1][0] (glyphs)"),
        (["1", "11", "layer"], #""highlights""#, "samples[1][11].layer (glyphs)"),
        (["1", "11", "unit"], "4", "samples[1][11].unit (glyphs)"),
        (["1", "13", "trackMatte", "mode"], #""alpha""#, "samples[1][13].trackMatte.mode (picture)"),
        (["1", "13", "trackMatte", "invert"], "true", "samples[1][13].trackMatte.invert (picture)"),
        (
            ["1", "13", "trackMatte", "source", "list", "items", "0", "origin"],
            "null",
            "samples[1][13].trackMatte.source.list.items[0].origin (path)"
        ),
        (["1", "13", "source", "list", "size"], "[200, 150]", "samples[1][13].source.list.size[0] (picture)"),
        (["1", "13", "source", "list", "background"], #""color(srgb 1 1 1 / 1)""#, "samples[1][13].source.list.background (picture)"),
        (["1", "13", "source", "list", "compositing"], #""linear""#, "samples[1][13].source.list.compositing (picture)"),
        (["1", "13", "source", "list", "items"], "[]", "samples[1][13].source.list.items (picture)"),
        (["1", "13", "source", "list", "items", "0", "blend"], #""screen""#, "samples[1][13].source.list.items[0].blend (path)"),
        (["1", "15", "filter", "0", "ops", "0", "file"], #""/abs/other.cube""#, "samples[1][15].filter[0].ops[0].file (adjust)"),
        (
            ["1", "15", "filter", "0", "ops", "0", "sha256"],
            "\"\(String(repeating: "b", count: 64))\"",
            "samples[1][15].filter[0].ops[0].sha256 (adjust)"
        ),
        (["1", "15", "filter", "0", "ops", "0", "space"], #""srgb-linear""#, "samples[1][15].filter[0].ops[0].space (adjust)"),
        (["1", "15", "filter", "0", "ops", "3", "file"], #""/abs/other.png""#, "samples[1][15].filter[0].ops[3].file (adjust)"),
        (
            ["1", "15", "filter", "0", "ops", "3", "sha256"],
            "\"\(String(repeating: "b", count: 64))\"",
            "samples[1][15].filter[0].ops[3].sha256 (adjust)"
        ),
        (["1", "15"], nil, "samples[1] (display list)"),
        (["1", "16", "source", "media", "file"], #""/abs/other.pdf""#, "samples[1][16].source.media.file (picture)"),
        (["1", "16", "source", "media", "page"], "1", "samples[1][16].source.media.page (picture)"),
        (["1", "16", "matte", "source", "page"], "1", "samples[1][16].matte.source.page (picture)")
    ]

    // A path in the second sample list and what is written there.
    private static let movedFields: [([String], String)] = [
        (["0", "transform"], "[1, 0, 0, 1, 5, 5]"),
        (["0", "opacity"], "0.25"),
        (["0", "reveal"], "[0, 0, 270, 1920]"),
        (["0", "mask", "1", "geometry"], #"{ "ellipse": { "rect": [1, 2, 3, 4] } }"#),
        (["0", "mask", "1", "transform"], "[1, 0, 0, 1, 0, 0]"),
        (["0", "mask", "1", "feather"], "2"),
        (["0", "rect"], "[0, 0, 100, 100]"),
        (["0", "dest"], "[0, 0, 10, 10]"),
        (["0", "filter", "0", "mix"], "1"),
        (["0", "filter", "0", "ops", "0", "ev"], "1"),
        (["0", "matte", "progress"], "0.75"),
        (["0", "radius"], "0"),
        (["0", "border", "width"], "0"),
        (["0", "border", "color"], #""color(srgb 1 0 0 / 1)""#),
        (["0", "shadow"], "null"),
        (["2", "fill"], #""color(srgb 1 1 1 / 1)""#),
        (["2", "shadow"], "null"),
        (["4", "geometry"], #"{ "rect": { "rect": [0, 0, 10, 10], "radius": 2 } }"#),
        (["4", "stroke", "width"], "3"),
        (["4", "stroke", "paint"], #""color(srgb 1 1 1 / 1)""#),
        (["4", "stroke", "dashOffset"], "1"),
        (["5", "stroke", "end", "scale"], "0.5"),
        (["4", "trim"], "[0, 1]"),
        (["6", "size"], "[100, 40]"),
        (["6", "background"], "null"),
        (["6", "runs", "0", "color"], #""color(srgb 1 0 0 / 1)""#),
        (["6", "runs", "0", "stroke"], "null"),
        (["6", "runs", "0", "highlight"], "null"),
        (["6", "runs", "0", "underline"], "null"),
        (["6", "runs", "0", "glyphs", "1", "1"], "20"),
        (["6", "runs", "0", "glyphs", "1", "2"], "30"),
        (["8", "filter", "0", "ops", "0", "amount"], "0.5"),
        (["11", "unitBox"], "[0, 0, 1, 1]"),
        (["11", "extent"], "[0, 0, 1, 1]"),
        (["12", "cornerPin"], "[[800, 300], [1131, 352], [1102, 918], [779, 861]]"),
        (["12", "cornerPin"], "[[0, 0], [0, 0], [0, 0], [0, 0]]"),
        (["13", "dest"], "[0, 0, 200, 150]"),
        (["13", "source", "list", "items", "0", "transform"], "[2, 0, 0, 2, 0, 0]"),
        (["13", "trackMatte", "source", "list", "items", "0", "opacity"], "0.5"),
        (["14", "filter", "0", "ops", "0", "amount"], "0.4"),
        (["15", "filter", "0", "ops", "0", "amount"], "0.25"),
        (["15", "filter", "0", "ops", "1", "radius"], "8"),
        (["15", "filter", "0", "ops", "1", "color"], #""color(srgb 1 0 0 / 1)""#),
        (["15", "filter", "0", "ops", "2", "input"], "[0, 1]"),
        (["15", "filter", "0", "ops", "2", "output"], "[0.1, 0.9]"),
        (["15", "filter", "0", "ops", "3", "amount"], "4"),
        (["15", "filter", "0", "ops", "3", "offset"], "[0, 0]"),
        (["16", "rect"], "[10, 5, 50, 25]"),
        (["16", "dest"], "[0, 0, 440, 220]")
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
            colorSpace: nil,
            seed: 12,
            items: [DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.grain(amount: 0.3, size: 2)])])))]
        )
        let nested = list(
            size: Size(width: 1080, height: 1500),
            colorSpace: nil,
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
            colorSpace: nil,
            seed: 7,
            items: [Self.items[5], DisplayItem(content: .adjust(AdjustItem(filter: [FilterEntry(operations: [.grain(amount: 0.3, size: 2)])])))]
        )
        let list = list(
            seed: 7,
            items: [
                DisplayItem(trackMatte: ItemTrackMatte(source: source, mode: .luma, isInverted: true), content: Self.items[2].content),
                DisplayItem(trackMatte: ItemTrackMatte(source: list(colorSpace: nil, seed: 7, items: []), mode: .alpha, isInverted: false), content: Self.items[2].content)
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
        let source = list(colorSpace: nil, items: [])
        let list = list(items: [
            DisplayItem(trackMatte: ItemTrackMatte(source: source, mode: .alpha, isInverted: false), content: Self.items[2].content),
            Self.items[2]
        ])

        // When
        let items = writer.document(list).objectValue?["items"]?.arrayValue?.compactMap(\.objectValue)

        // Then
        #expect(items?.first?.keys.prefix(8) == ["item", "origin", "transform", "opacity", "blend", "mask", "trackMatte", "reveal"])
        #expect(items?.first?["trackMatte"] == (try Fixture.json(#"""
            { "source": { "list": { "size": [1080, 1920], "background": "color(srgb 0 0 0 / 1)", "compositing": "encoded", "items": [] } },
              "mode": "alpha", "invert": false }
            """#)))
        #expect(items?.last?["trackMatte"] == .null)
    }

    @Test("a track matte's source of another size than the list holding its item stops, naming both sizes")
    func refusesTrackMatteSize() throws {
        // Given
        let source = list(size: Size(width: 540, height: 960), colorSpace: nil, items: [])
        let list = list(items: [
            DisplayItem(trackMatte: ItemTrackMatte(source: source, mode: .alpha, isInverted: false), content: Self.items[2].content)
        ])

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(writer.write(list)) }

        // Then
        #expect(error?.description == "items[0].trackMatte.source (path): the track matte's source is 540 by 960, and a track matte's source is the size of the list that holds its item, 1080 by 1920")
    }

    @Test("a page source is written with its page, frame null and target peak null, and reads back, as a page matte does")
    func writesPageSource() throws {
        // Given
        let matte = PictureMatte(
            frame: MediaFrame(media: Self.page, index: 0, reading: .analysis(colorSpace: nil)),
            progress: 0.5,
            softness: 0.1,
            isInverted: false
        )
        let picture = PictureItem(
            source: .media(MediaFrame(media: Self.page, index: 0, reading: .working(colorSpace: .srgb, targetPeak: 203))),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 1080, height: 1920),
            matte: matte
        )
        let list = list(items: [DisplayItem(content: .picture(picture))])

        // When
        let written = writer.write(list)
        let read = try sut.read(written)

        // Then
        #expect(written.contains(#""page": 3"#))
        #expect(written.ranges(of: #""frame": null"#).count == 2)
        #expect(written.contains(#""targetPeak": 203"#) == false)
        #expect(read == list)
    }

    @Test("a page source with a frame index stops, naming its place")
    func refusesFrameOfPage() throws {
        // Given
        let picture = PictureItem(
            source: .media(MediaFrame(media: Self.page, index: 0)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 1080, height: 1920)
        )
        let text = replacingFirst(
            #""frame": null"#,
            with: #""frame": 0"#,
            in: writer.write(list(items: [DisplayItem(content: .picture(picture))]))
        )

        // When
        let error = #expect(throws: (any Error).self) { try sut.read(text) }

        // Then
        #expect(
            (error as? CustomStringConvertible)?.description
                == "items[0].source.frame (picture): frame 0 is given for a page of a PDF, which is read by region and "
                + "scale, so its frame is null"
        )
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

    @Test("a picture writes its corner pin as four points after its shadow, and null without one")
    func writesCornerPin() throws {
        // Given
        let list = list(items: [Self.items[1], Self.items[Self.items.count - 1]])

        // When
        let items = writer.document(list).objectValue?["items"]?.arrayValue?.compactMap(\.objectValue)

        // Then
        #expect(items?[0].members.last?.key == "cornerPin")
        #expect(items?[0]["cornerPin"] == .null)
        #expect(items?[1]["cornerPin"] == (try Fixture.json("[[812, 304], [1131, 352], [1102, 918], [779, 861]]")))
    }

    @Test(
        "a picture's corner pin that is not four points or not strictly convex stops, naming its place",
        arguments: [
            ("[[0, 0], [10, 0], [10, 10]]", "items[0].cornerPin (picture): expected a list of 4 points, found a list of 3"),
            ("[[0, 0], [10, 0], [10, 10], [10, 20]]", "items[0].cornerPin (picture): a corner pin is a strictly convex quadrilateral, found [[0, 0], [10, 0], [10, 10], [10, 20]]"),
            ("[[0, 0], [0, 0], [0, 0], [0, 0]]", "items[0].cornerPin (picture): a corner pin is a strictly convex quadrilateral, found [[0, 0], [0, 0], [0, 0], [0, 0]]")
        ]
    )
    func refusesCornerPin(
        written: String,
        message: String
    ) throws {
        // Given
        let text = #"""
            { "displayList": "\#(FramesVersion.current)", "size": [10, 10], "background": "color(srgb 0 0 0 / 1)", "colorSpace": "srgb",
              "peak": null, "compositing": "encoded", "items": [
              { "item": "picture", "origin": null, "transform": [1, 0, 0, 1, 0, 0], "opacity": 1, "blend": "normal", "mask": null,
                "trackMatte": null, "reveal": null, "source": { "list": { "size": [10, 10], "background": "color(srgb 0 0 0 / 0)",
                "compositing": "encoded", "items": [] } }, "rect": null, "dest": [0, 0, 10, 10], "filter": [], "matte": null,
                "radius": 0, "border": null, "shadow": null, "cornerPin": \#(written) } ] }
            """#

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a picture of a media frame with a corner pin stops, naming its corner pin")
    func refusesMediaCornerPin() throws {
        // Given
        let media = PictureItem(
            source: .media(MediaFrame(media: Self.still, index: 0)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 100, height: 60),
            cornerPin: Quad(Rectangle(x: 10, y: 10, width: 100, height: 60))
        )
        let text = writer.write(list(items: [DisplayItem(content: .picture(media))]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == "items[0].cornerPin (picture): a picture of a media frame carries no corner pin")
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
        "a mask list that is empty, or a mask that is not a closed path, has a missing key, a negative feather or an unknown mode stops",
        arguments: [
            ("[]", "items[0].mask (path): a mask list holds at least one mask, and an item without one has null"),
            (
                #"[{ "geometry": { "path": { "vertices": [[0, 0], [4, 0], [2, 4]], "inTangents": [[0, 0], [0, 0], [0, 0]], "outTangents": [[0, 0], [0, 0], [0, 0]], "closed": false } }, "transform": [1, 0, 0, 1, 0, 0], "feather": 0, "invert": false, "mode": "add" }]"#,
                "items[0].mask[0].geometry (path): a path mask is a closed path"
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
            { "displayList": "\#(FramesVersion.current)", "size": [10, 10], "background": "color(srgb 0 0 0 / 1)", "colorSpace": "srgb",
              "peak": null, "compositing": "encoded", "items": [
              { "item": "path", "origin": null, "transform": [1, 0, 0, 1, 0, 0], "opacity": 1, "blend": "normal",
                "mask": \#(written), "trackMatte": null, "reveal": null, "geometry": { "rect": { "rect": [0, 0, 1, 1], "radius": 0 } },
                "fill": "color(srgb 1 1 1 / 1)", "stroke": null, "trim": [0, 1], "shadow": null } ] }
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
            colorSpace: nil,
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
        arguments: ["0.2.0", "1.0.0"]
    )
    func refusesOtherVersion(version: String) throws {
        // Given
        let text = replacingFirst(#""displayList": "0.1.0""#, with: #""displayList": "\#(version)""#, in: written())

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"""
            displayList (display list): the display list was written by frames "\#(version)", and frames 0.1.0 reads \#
            only one written by frames 0.0 up to 0.1
            """#)
    }

    @Test(
        "a member that is missing, of another type, or never written there stops, naming its place",
        arguments: [
            (#""displayList": "0.1.0","#, "", #"top level (display list): missing key "displayList""#),
            (#""trim": [0.125, 0.625]"#, #""trimmed": [0.125, 0.625]"#, #"items[4] (path): unknown key "trimmed". Allowed: item, origin, transform, opacity, blend, mask, trackMatte, reveal, geometry, fill, stroke, trim, shadow"#),
            (#""rect": [0, 0, 1080, 1920],"#, "", #"items[2].geometry.rect (path): missing key "rect""#),
            (#""blend": "multiply""#, #""blend": "linear-dodge""#, #"items[0].blend (picture): unknown value "linear-dodge". Allowed: normal, multiply, screen, overlay, darken, lighten, color-dodge, color-burn, hard-light, soft-light, difference, exclusion, plus-lighter, hue, saturation, color, luminosity, add"#),
            (#""item": "path""#, #""item": "line""#, #"items[2].item (display item): unknown value "line". Allowed: picture, path, glyphs, adjust"#),
            (#""frame": 2"#, #""frame": 3"#, "items[0].source.frame (picture): frame 3 is not a frame of the media, whose frames are 0 to 2"),
            (#""opacity": 0.75"#, #""opacity": "0.75""#, #"items[6].opacity (glyphs): expected a number, found "0.75""#),
            (#""layer": "strokes""#, #""layer": "glow""#, #"items[11].layer (glyphs): unknown value "glow". Allowed: highlights, underlines, strokes, fills"#),
            (#""layer": "strokes""#, #""layer": null"#, "items[11] (glyphs): a unit's item carries layer, unit and unitBox, and a title's own item none of them, found only unit and unitBox"),
            (#""unit": 3"#, #""unit": null"#, "items[11] (glyphs): a unit's item carries layer, unit and unitBox, and a title's own item none of them, found only layer and unitBox"),
            (#""unitBox": [2, 1, 6, 8]"#, #""unitBox": null"#, "items[11] (glyphs): a unit's item carries layer, unit and unitBox, and a title's own item none of them, found only layer and unit"),
            (#""unit": null"#, #""unit": 0"#, "items[6] (glyphs): a unit's item carries layer, unit and unitBox, and a title's own item none of them, found only unit"),
            (#""bands": ["#, #""bands": [[30, 40], "#, "items[6].runs[0].highlight.bands (glyphs): expected a band for each rect, 1 in all, found a list of 2"),
            (#"[43, 12, 36]"#, #"[65536, 12, 36]"#, #"items[6].runs[0].glyphs[0] (glyphs): expected [glyph id, x, y] with a glyph id from 0 to 65535, found a list of 3"#)
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
        #expect(item["stroke"]?.objectValue?.keys == ["width", "paint", "align", "join", "cap", "start", "end", "dash", "dashOffset"])
        #expect(item["geometry"] == (try Fixture.json(#"""
            { "path": { "vertices": [[240, 175], [300, 175]], "inTangents": [[0, 0], [-10, -15.5]],
                        "outTangents": [[20, -30], [0, 0]], "closed": false } }
            """#)))
    }

    @Test("a unit's item writes its unit beside its unit box, and its origin names only the clip that drew it")
    func writesUnitOfGlyphs() throws {
        // Given
        let list = list(items: [Self.items[6], Self.items[11]])

        // When
        let written = writer.document(list).objectValue?["items"]?.arrayValue
        let items = try #require(written).compactMap(\.objectValue)

        // Then
        #expect(items.map(\.keys) == Array(repeating: [
            "item", "origin", "transform", "opacity", "blend", "mask", "trackMatte", "reveal", "size", "writingMode", "runs",
            "layer", "unit", "unitBox", "extent", "background"
        ], count: 2))
        #expect(items.map { $0["unit"] } == [.null, .number(3)])
        #expect(items.map { $0["origin"]?.objectValue?.keys } == [["place", "id", "kind"], ["place", "id", "kind"]])
    }

    @Test("a vertical glyphs item reads back as written, with its writing mode, its runs turned or not, narrowed or not, and its bands")
    func roundTripsVerticalGlyphs() throws {
        // Given
        let run = { (isSideways: Bool, horizontalScale: Double) in
            DrawnGlyphRun(
                font: PinnedFile(path: "/abs/Inter.ttf", sha256: Self.hash),
                face: "Inter-Regular",
                size: 40,
                isSideways: isSideways,
                horizontalScale: horizontalScale,
                color: Color(written: "#FF0000"),
                stroke: nil,
                highlight: DrawnHighlight(
                    rects: [Rectangle(x: 0, y: 10, width: 40, height: 60)],
                    radius: 2,
                    color: Color(written: "#00FF00"),
                    bands: [20...45]
                ),
                underline: DrawnUnderline(
                    rects: [Rectangle(x: 3, y: 10, width: 2, height: 60)],
                    color: Color(written: "#0000FF"),
                    bands: [20...45]
                ),
                glyphs: [PositionedGlyph(id: 7, x: 8, y: 30)]
            )
        }
        let item = DisplayItem(content: .glyphs(GlyphsItem(
            size: Size(width: 40, height: 80),
            writingMode: .verticalRightToLeft,
            runs: [run(false, 0.5), run(true, 1)],
            unit: UnitDrawing(layer: .highlights, index: 0, box: Rectangle(x: 0, y: 20, width: 40, height: 25)),
            extent: Rectangle(x: 0, y: 20, width: 40, height: 25),
            background: nil
        )))
        let list = list(items: [item])

        // When
        let written = writer.document(list).objectValue?["items"]?.arrayValue?.first?.objectValue
        let read = try sut.read(writer.write(list))

        // Then
        #expect(written?["writingMode"] == .string("vertical-rl"))
        #expect(written?["runs"]?.arrayValue?.map { $0.objectValue?["sideways"] } == [.bool(false), .bool(true)])
        #expect(written?["runs"]?.arrayValue?.map { $0.objectValue?["horizontalScale"] } == [.number(0.5), .number(1)])
        #expect(read == list)
    }

    @Test("a list whose fills items name its units 0, 1, 2 and on in order reads back, between items of other layers")
    func readsFillsInUnitOrder() throws {
        // Given
        let list = list(items: [unitItem(unit: 0, layer: .strokes), unitItem(unit: 1, layer: .strokes), unitItem(unit: 0), unitItem(unit: 1)])

        // When
        let read = try sut.read(writer.write(list))

        // Then
        #expect(read == list)
    }

    @Test(
        "a list whose fills items do not name its units 0, 1, 2 and on in order stops, naming the first item out of order",
        arguments: [
            ([1, 0], "items[0].unit (glyphs): the list's fills items name the units 0, 1, 2 and on in order, and this one names unit 1 in place of 0"),
            ([0, 2], "items[1].unit (glyphs): the list's fills items name the units 0, 1, 2 and on in order, and this one names unit 2 in place of 1"),
            ([0, 0], "items[1].unit (glyphs): the list's fills items name the units 0, 1, 2 and on in order, and this one names unit 0 in place of 1")
        ]
    )
    func refusesFillsOutOfUnitOrder(
        units: [Int],
        message: String
    ) throws {
        // Given
        let list = list(items: units.map { unitItem(unit: $0) })

        // When
        let error = #expect(throws: (any Error).self) { try sut.read(writer.write(list)) }

        // Then
        #expect((error as? CustomStringConvertible)?.description == message)
    }

    @Test("a fill and a stroke paint are a colour or a gradient of one member named by its kind, its stops [offset, colour]")
    func writesPaint() throws {
        // Given
        let list = list(items: [Self.items[10]])

        // When
        let item = try #require(writer.document(list).objectValue?["items"]?.arrayValue?.first?.objectValue)

        // Then
        #expect(item["fill"] == (try Fixture.json(##"""
            { "linear": { "from": [10, 20], "to": [210, 20], "stops": [[0, "color(srgb 1 0 0 / 0)"], [1, "color(srgb 0 0 1 / 1)"]] } }
            """##)))
        #expect(item["stroke"]?.objectValue?["paint"] == (try Fixture.json(##"""
            { "radial": { "center": [110, 70], "radius": 111.8, "stops": [[0, "color(srgb 1 1 1 / 1)"], [0.5, "color(srgb 1 1 1 / 1)"], [0.5, "color(srgb 0 0 0 / 0.5019607843137255)"]] } }
            """##)))
        let colored = try #require(writer.document(self.list(items: [Self.items[5]])).objectValue?["items"]?.arrayValue?.first?.objectValue)
        #expect(colored["stroke"]?.objectValue?["paint"] == .string("color(srgb 1 0.23137254901960785 0.18823529411764706 / 1)"))
    }

    @Test(
        "a path whose geometry, stroke literal or trim is not of the JSON form stops, naming its place",
        arguments: [
            (
                #"{ "path": { "vertices": [[1, 2]], "inTangents": [[0, 0]], "outTangents": [[0, 0]], "closed": false } }"#,
                "geometry",
                "items[0].geometry.path.vertices (path): a path runs through at least two vertices, found 1"
            ),
            (
                #"{ "path": { "vertices": [[1, 2], [3, 4]], "inTangents": [[0, 0], [0, 0]], "outTangents": [[0, 0]], "closed": false } }"#,
                "geometry",
                "items[0].geometry.path.outTangents (path): a path has a tangent for each of its 2 vertices, found 1"
            ),
            (
                #"{ "rect": { "rect": [0, 0, 1, 1], "radius": 0 }, "ellipse": { "rect": [0, 0, 1, 1] } }"#,
                "geometry",
                #"items[0].geometry (path): takes only one of "rect", "ellipse""#
            ),
            ("{}", "geometry", "items[0].geometry (path): needs one of rect, ellipse, path"),
            (
                #"{ "spline": { "points": [[0, 0], [1, 1]] } }"#,
                "geometry",
                #"items[0].geometry (path): unknown key "spline". Allowed: rect, ellipse, path"#
            ),
            (
                #"{ "ellipse": { "rect": [0, 0, 1, 1], "radius": 2 } }"#,
                "geometry",
                #"items[0].geometry.ellipse (path): unknown key "radius". Allowed: rect"#
            ),
            (
                ##"{ "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "center", "join": "sharp", "cap": "butt", "start": null, "end": null }"##,
                "stroke",
                #"items[0].stroke.join (path): unknown value "sharp". Allowed: miter, round, bevel"#
            ),
            (
                ##"{ "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "center", "join": "round", "cap": "flat", "start": null, "end": null }"##,
                "stroke",
                #"items[0].stroke.cap (path): unknown value "flat". Allowed: butt, round, square"#
            ),
            (
                ##"{ "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "center", "join": "round", "cap": "butt", "start": null, "end": { "shape": "dot", "scale": 1 } }"##,
                "stroke",
                #"items[0].stroke.end.shape (path): unknown value "dot". Allowed: arrow, line-arrow, circle, square, diamond, bar"#
            ),
            (
                ##"{ "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "center", "join": "round", "cap": "butt", "start": null, "end": "arrow" }"##,
                "stroke",
                #"items[0].stroke.end (path): expected an object, found "arrow""#
            ),
            (
                ##"{ "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "center", "join": "round", "cap": "butt", "start": "none", "end": null }"##,
                "stroke",
                #"items[0].stroke.start (path): expected an object, found "none""#
            ),
            (
                ##"{ "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "center", "join": "round", "cap": "butt", "start": { "shape": "none", "scale": 1 }, "end": null }"##,
                "stroke",
                #"items[0].stroke.start.shape (path): unknown value "none". Allowed: arrow, line-arrow, circle, square, diamond, bar"#
            ),
            (
                ##"{ "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "center", "join": "round", "cap": "butt", "start": null, "end": { "shape": "arrow", "size": 1 } }"##,
                "stroke",
                #"items[0].stroke.end (path): unknown key "size". Allowed: shape, scale"#
            ),
            (
                ##"{ "width": 2, "paint": { "linear": { "from": [0, 0], "to": [1, 0], "stops": [[0, "color(srgb 1 1 1 / 1)"]] } }, "join": "round", "cap": "butt", "start": null, "end": null }"##,
                "stroke",
                "items[0].stroke.paint.linear.stops (path): a gradient has at least two stops, their offsets from 0 to 1 and in order"
            ),
            (
                ##"{ "width": 2, "paint": { "radial": { "center": [0, 0], "radius": 1, "stops": [[0.5, "color(srgb 1 1 1 / 1)"], [0.2, "color(srgb 0 0 0 / 1)"]] } }, "join": "round", "cap": "butt", "start": null, "end": null }"##,
                "stroke",
                "items[0].stroke.paint.radial.stops (path): a gradient has at least two stops, their offsets from 0 to 1 and in order"
            ),
            (
                ##"{ "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "middle", "join": "round", "cap": "butt", "start": null, "end": null }"##,
                "stroke",
                #"items[0].stroke.align (path): unknown value "middle". Allowed: inside, center, outside"#
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
            { "displayList": "\#(FramesVersion.current)", "size": [10, 10], "background": "color(srgb 0 0 0 / 1)", "colorSpace": "srgb",
              "peak": null, "compositing": "encoded", "items": [
              { "item": "path", "origin": null, "transform": [1, 0, 0, 1, 0, 0], "opacity": 1, "blend": "normal",
                "mask": null, "trackMatte": null, "reveal": null, "geometry": \#(members["geometry"] ?? ""),
                "fill": "color(srgb 1 1 1 / 1)",
                "stroke": \#(members["stroke"] ?? ""), "trim": \#(members["trim"] ?? ""), "shadow": null } ] }
            """#

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a path's stroke and a picture's border are written with their align and read back with it", arguments: StrokeAlign.allCases)
    func readsWrittenAlign(align: StrokeAlign) throws {
        // Given
        let list = list(items: [
            DisplayItem(content: .picture(PictureItem(
                source: .media(MediaFrame(media: Self.still, index: 0)),
                rectangle: nil,
                destination: Rectangle(x: 10, y: 20, width: 200, height: 100),
                border: MediaBorder(width: 4, color: Color(written: "#FFFFFF"), align: align)
            ))),
            DisplayItem(content: .path(PathItem(
                geometry: .rect(Rectangle(x: 10, y: 20, width: 200, height: 100), radius: 8),
                fill: nil,
                stroke: PathStroke(width: 4, paint: .color(Color(written: "#FF3B30")), align: align, join: .miter, cap: .butt, start: .none, end: .none)
            )))
        ])

        // When
        let text = writer.write(list)
        let read = try sut.read(text)

        // Then
        let items = try #require(try Fixture.json(text).objectValue?["items"]?.arrayValue?.compactMap(\.objectValue))
        #expect(items.map { ($0["border"] ?? $0["stroke"])?.objectValue?["align"] } == [.string(align.rawValue), .string(align.rawValue)])
        #expect(read == list)
    }

    @Test(
        "a path's stroke ends are written as null for no head or as the head's shape and scale, and read back",
        arguments: StrokeEndShape.allCases
    )
    func readsWrittenEnds(shape: StrokeEndShape) throws {
        // Given
        let list = list(items: [
            DisplayItem(content: .path(PathItem(
                geometry: .polyline([Point(x: 10, y: 20), Point(x: 200, y: 20)], isClosed: false),
                fill: nil,
                stroke: PathStroke(
                    width: 4,
                    paint: .color(Color(written: "#FF3B30")),
                    join: .miter,
                    cap: .butt,
                    start: StrokeEnd(shape: shape, scale: 2.5),
                    end: StrokeEnd(shape: shape)
                )
            )))
        ])

        // When
        let text = writer.write(list)
        let read = try sut.read(text)

        // Then
        let items = try #require(try Fixture.json(text).objectValue?["items"]?.arrayValue?.compactMap(\.objectValue))
        let stroke = try #require(items.first?["stroke"]?.objectValue)
        let written = { (scale: Double) -> JSONValue in
            shape == .none
                ? .null
                : .object(JSONObject(members: [
                    JSONMember(key: "shape", value: .string(shape.rawValue)),
                    JSONMember(key: "scale", value: .number(scale))
                ]))
        }
        #expect(stroke["start"] == written(2.5))
        #expect(stroke["end"] == written(1))
        if shape == .none {
            #expect(read.items.first.map { item -> Bool in
                guard case let .path(path) = item.content else { return false }

                return path.stroke?.start == StrokeEnd.none && path.stroke?.end == StrokeEnd.none
            } == true)
        } else {
            #expect(read == list)
        }
    }

    @Test(
        "a stroke inside or outside its outline on an open path or with an arrowhead stops, naming its stroke",
        arguments: [
            (#"{ "path": { "vertices": [[0, 0], [5, 5], [10, 0]], "inTangents": [[0, 0], [0, 0], [0, 0]], "outTangents": [[0, 0], [0, 0], [0, 0]], "closed": false } }"#, "inside", "null"),
            (#"{ "rect": { "rect": [0, 0, 1, 1], "radius": 0 } }"#, "outside", #"{ "shape": "circle", "scale": 1 }"#)
        ]
    )
    func refusesAlignedStrokeOffClosedOutline(
        geometry: String,
        align: String,
        end: String
    ) throws {
        // Given
        let text = #"""
            { "displayList": "\#(FramesVersion.current)", "size": [10, 10], "background": "color(srgb 0 0 0 / 1)", "colorSpace": "srgb",
              "peak": null, "compositing": "encoded", "items": [
              { "item": "path", "origin": null, "transform": [1, 0, 0, 1, 0, 0], "opacity": 1, "blend": "normal",
                "mask": null, "trackMatte": null, "reveal": null, "geometry": \#(geometry), "fill": null,
                "stroke": { "width": 2, "paint": "color(srgb 1 1 1 / 1)", "align": "\#(align)", "join": "round", "cap": "butt",
                            "start": null, "end": \#(end), "dash": null, "dashOffset": 0 },
                "trim": [0, 1], "shadow": null } ] }
            """#

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == "items[0].stroke (path): a stroke inside or outside its outline needs a closed outline and no arrowhead")
    }

    @Test("a list with samples reads back and writes the same text again, its seed from a grain in its samples")
    func readsWrittenSamples() throws {
        // Given
        let moved = Self.sampleItems.enumerated().map { index, item in
            DisplayItem(
                transform: AffineTransform(a: 1, b: 0, c: 0, d: 1, tx: Double(index), ty: 0),
                opacity: item.opacity / 2,
                blend: item.blend,
                mask: item.mask,
                trackMatte: item.trackMatte,
                reveal: item.reveal,
                content: item.content,
                origin: item.origin
            )
        }
        let list = DisplayList(
            size: Size(width: 1080, height: 1920),
            background: Color(written: "#000000"),
            colorSpace: .srgb,
            seed: 7,
            samples: [Self.sampleItems, moved, Self.sampleItems]
        )

        // When
        let read = try sut.read(writer.write(list))

        // Then
        #expect(writer.write(read) == writer.write(list))
        #expect(read.seed == 7)
        #expect(read.samples?.count == 3)
    }

    @Test("a list with samples writes them after its compositing, each a list of items, in place of its items")
    func writesSamplesMembers() throws {
        // Given
        let list = samplesList()

        // When
        let document = writer.document(list).objectValue
        let samples = document?["samples"]?.arrayValue

        // Then
        #expect(document?.keys == ["displayList", "size", "background", "colorSpace", "peak", "compositing", "samples"])
        #expect(samples?.count == 2)
        #expect(samples?.first == writer.document(self.list(items: Self.sampleItems)).objectValue?["items"])
    }

    @Test(
        "an outermost list with both items and samples or neither, samples of fewer than two lists, or samples in a nested list stops",
        arguments: samplesForms
    )
    func refusesSamplesForm(
        path: [String],
        value: JSONValue?,
        message: String
    ) throws {
        // Given
        let text = try writtenSamples(replacing: path, with: value)

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test(
        "a sample list that differs from the first in a field the Moves columns do not mark stops, naming its place",
        arguments: unmovedFields
    )
    func refusesDifferentSample(
        path: [String],
        written: String?,
        place: String
    ) throws {
        // Given
        let text = try writtenSamples(replacing: ["samples"] + path, with: written.map(Fixture.json))

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == """
            \(place): differs from the first sample list, and the sample lists of a frame hold the same items in the same \
            order and differ only in the fields that move
            """)
    }

    @Test(
        "a sample list that differs from the first only in fields the Moves columns mark reads",
        arguments: movedFields
    )
    func readsMovedSample(
        path: [String],
        written: String
    ) throws {
        // Given
        let text = try writtenSamples(replacing: ["samples", "1"] + path, with: Fixture.json(written))

        // When
        let read = try sut.read(text)

        // Then
        #expect(read.samples?.count == 2)
        #expect(read.samples?.first == Self.sampleItems)
        #expect(read.samples?.last != Self.sampleItems)
    }

    @Test(
        "a corner pin in a sample list that is neither strictly convex nor four points at [0, 0] stops, naming its place",
        arguments: ["[[1, 1], [1, 1], [1, 1], [1, 1]]", "[[0, 0], [10, 0], [10, 10], [10, 20]]"]
    )
    func refusesCornerPinInSample(written: String) throws {
        // Given
        let text = try writtenSamples(replacing: ["samples", "1", "12", "cornerPin"], with: Fixture.json(written))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == """
            samples[1][12].cornerPin (picture): a corner pin in a sample list is a strictly convex quadrilateral or four \
            points at [0, 0], found \(written)
            """)
    }

    @Test("a grain in a later sample list with a seed other than the first grain's stops, naming its place")
    func refusesDifferentSeedInSample() throws {
        // Given
        let text = try writtenSamples(replacing: ["samples", "1", "14", "filter", "0", "ops", "0", "seed"], with: .number(5))

        // When
        let error = #expect(throws: EvaluateError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == """
            samples[1][14].filter[0].ops[0].seed (adjust): seed 5 differs from 0, the seed of the first grain in the list, \
            and every grain of an output frame takes that frame's number
            """)
    }

    // MARK: - Private
    // The outermost list with two equal sample lists of `sampleItems`.
    private func samplesList() -> DisplayList {
        DisplayList(
            size: Size(width: 1080, height: 1920),
            background: Color(written: "#000000"),
            colorSpace: .srgb,
            seed: 0,
            samples: [Self.sampleItems, Self.sampleItems]
        )
    }

    // `samplesList()` written, with `value` put at `path`, or what is there removed where `value` is nil. A component
    // names a key of an object, or the index of an element of a list.
    private func writtenSamples(
        replacing path: [String],
        with value: JSONValue?
    ) throws -> String {
        let document = try JSONReader().read(writer.write(samplesList()))

        return try JSONWriter().write(#require(replacing(path[...], with: value, in: document)))
    }

    private func replacing(
        _ path: ArraySlice<String>,
        with value: JSONValue?,
        in written: JSONValue
    ) -> JSONValue? {
        guard let component = path.first else { return value }

        switch written {
        case let .object(object):
            guard let member = object[component] ?? (path.count == 1 ? .null : nil) else {
                Issue.record("\(component) is not a key of the object")
                return written
            }
            guard let replaced = replacing(path.dropFirst(), with: value, in: member) else {
                return .object(JSONObject(members: object.members.filter { $0.key != component }))
            }

            return .object(object.setting(component, to: replaced))

        case var .array(elements):
            guard let index = Int(component), elements.indices.contains(index) else {
                Issue.record("\(component) is not an index of the list")
                return written
            }
            guard let replaced = replacing(path.dropFirst(), with: value, in: elements[index]) else {
                elements.remove(at: index)
                return .array(elements)
            }

            elements[index] = replaced
            return .array(elements)

        default:
            Issue.record("\(component) names a member of a value that has none")
            return written
        }
    }

    // A unit's item with no runs, of `layer`, of the unit at `unit`.
    private func unitItem(
        unit: Int,
        layer: GlyphLayer = .fills
    ) -> DisplayItem {
        DisplayItem(content: .glyphs(GlyphsItem(
            size: Size(width: 10, height: 10),
            runs: [],
            unit: UnitDrawing(layer: layer, index: unit, box: Rectangle(x: 0, y: 0, width: 5, height: 10)),
            extent: Rectangle(x: 0, y: 0, width: 5, height: 10),
            background: nil
        )))
    }

    // The outermost list by default, which carries a colour space; a nested one carries none.
    private func list(
        size: Size = Size(width: 1080, height: 1920),
        colorSpace: ColorSpace? = .srgb,
        seed: Int = 0,
        items: [DisplayItem]
    ) -> DisplayList {
        DisplayList(size: size, background: Color(written: "#000000"), colorSpace: colorSpace, seed: seed, items: items)
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
