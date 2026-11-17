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

    // Items that between them hold every kind and every optional member, set and null.
    private static let items: [DisplayItem] = [
        DisplayItem(
            transform: rotation,
            opacity: 0.5,
            blend: "multiply",
            mask: Rectangle(x: 0, y: 0, width: 1080, height: 1500),
            reveal: Rectangle(x: 0, y: 0, width: 540, height: 1920),
            content: .picture(PictureItem(
                source: .media(MediaFrame(media: video, index: 2)),
                rectangle: Rectangle(x: 45, y: 97.5, width: 990, height: 1760),
                destination: Rectangle(x: 10, y: 20, width: 495, height: 880),
                filter: [.exposure(ev: 0.5), .blur(radius: 2)],
                matte: PictureMatte(frame: MediaFrame(media: still, index: 0), progress: 0.25, softness: 0.1, isInverted: true),
                radius: 12,
                border: MediaBorder(width: 4, color: Color(written: "#FFFFFF")),
                shadow: MediaShadow(radius: 8, offset: Point(x: 0, y: 6), color: Color(written: "#00000080"))
            )),
            origin: origin
        ),
        DisplayItem(content: .picture(PictureItem(
            source: .media(MediaFrame(media: imageSequence, index: 1)),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 1080, height: 1920)
        ))),
        DisplayItem(
            content: .fill(FillItem(
                rectangle: Rectangle(x: 0, y: 0, width: 1080, height: 1920),
                radius: 0,
                color: Color(written: "#00000099"),
                hole: RoundedRectangle(rectangle: Rectangle(x: 100, y: 200, width: 300, height: 120), radius: 16)
            )),
            origin: ItemOrigin(place: "clips[3]", id: nil, kind: "dim")
        ),
        DisplayItem(content: .fill(FillItem(rectangle: Rectangle(x: 0, y: 1500, width: 1080, height: 420), color: Color(written: "#000000")))),
        DisplayItem(
            transform: AffineTransform(a: 1.2, b: 0, c: 0, d: 1.2, tx: -54, ty: -96),
            content: .stroke(StrokeItem(
                rectangle: Rectangle(x: 150, y: 150, width: 100, height: 50),
                radius: 8,
                width: 6,
                color: Color(written: "#FF3B30"),
                trim: 0.625
            ))
        ),
        DisplayItem(content: .arrow(ArrowItem(
            tail: Point(x: 240, y: 175),
            head: Point(x: 300, y: 175),
            width: 6,
            headSize: 24,
            color: Color(written: "#FF3B30")
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
                    glyphs: [PositionedGlyph(id: 43, x: 12, y: 36), PositionedGlyph(id: 76, x: 34.5, y: 36)]
                )],
                stroke: TextStroke(width: 2, color: Color(written: "#000000")),
                background: GlyphBackground(rectangle: Rectangle(x: 0, y: 0, width: 120, height: 48), radius: 6, color: Color(written: "#111111CC"))
            )),
            origin: ItemOrigin(place: "clips[0]", id: nil, kind: "title")
        ),
        DisplayItem(content: .glyphs(GlyphsItem(size: Size(width: 10, height: 10), runs: [], stroke: nil, background: nil))),
        DisplayItem(content: .adjust(AdjustItem(rectangle: nil, filter: [.saturation(amount: 0)]))),
        DisplayItem(content: .adjust(AdjustItem(rectangle: Rectangle(x: 0, y: 0, width: 10, height: 10), filter: [])))
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
                DisplayItem(content: .adjust(AdjustItem(rectangle: nil, filter: filter))),
                DisplayItem(content: .picture(PictureItem(
                    source: .media(MediaFrame(media: Self.still, index: 0)),
                    rectangle: nil,
                    destination: Rectangle(x: 0, y: 0, width: 10, height: 10),
                    filter: filter
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
            DisplayItem(blend: blend, content: .fill(FillItem(rectangle: Rectangle(x: 0, y: 0, width: 1, height: 1), color: Color(written: "#FFFFFF"))))
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
            items: [DisplayItem(content: .adjust(AdjustItem(rectangle: nil, filter: [.grain(amount: 0.3, size: 2)])))]
        )
        let unit = list(
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
                mask: Rectangle(x: 0, y: 0, width: 1080, height: 1500),
                content: .picture(PictureItem(
                    source: .displayList(unit),
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

    @Test("a grain with a seed other than the first grain's stops, naming its place")
    func refusesDifferentSeed() throws {
        // Given
        let inner = list(
            seed: 4,
            items: [DisplayItem(content: .adjust(AdjustItem(rectangle: nil, filter: [.grain(amount: 0.3, size: 2)])))]
        )
        let list = list(
            seed: 3,
            items: [
                DisplayItem(content: .adjust(AdjustItem(rectangle: nil, filter: [.grain(amount: 0.3, size: 2)]))),
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
            items[1].source.list.items[0].filter[0].seed (adjust): seed 4 differs from 3, the seed of the first grain \
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
            (#""trim": 0.625"#, #""trimmed": 0.625"#, #"items[4] (stroke): unknown key "trimmed". Allowed: item, origin, transform, opacity, blend, mask, reveal, rect, radius, width, color, trim"#),
            (#""headSize": 24,"#, "", #"items[5] (arrow): missing key "headSize""#),
            (#""blend": "multiply""#, #""blend": "add""#, #"items[0].blend (picture): unknown value "add". Allowed: normal, multiply, screen, overlay, darken, lighten, color-dodge, color-burn, hard-light, soft-light, difference, exclusion, plus-lighter"#),
            (#""item": "arrow""#, #""item": "line""#, #"items[5].item (display item): unknown value "line". Allowed: picture, fill, stroke, arrow, glyphs, adjust"#),
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
