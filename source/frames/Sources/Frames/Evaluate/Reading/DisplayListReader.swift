//
//  DisplayListReader.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Reads a display list from its JSON text as `DisplayListWriter` writes it, by the rule a resolved document is read
// by: its version is checked before anything else, and a member that is missing or of another type, or a key the
// writer never writes there, stops naming its place. The list keeps one seed for itself and every list nested in it,
// so the seed of the first `grain` written is taken and a `grain` with another stops. A list with no `grain` reads
// with seed 0, since only `grain` reads the seed.
package struct DisplayListReader: Sendable {
    // MARK: - Property
    private static let listKeys = ["size", "background", "items"]
    private static let itemKeys = ["item", "origin", "transform", "opacity", "blend", "mask", "reveal"]
    private static let itemNames = ["picture", "path", "glyphs", "adjust"]
    private static let geometryForms = ["rect", "ellipse", "polyline"]

    private let checker: ResolvedDocumentChecker
    private let values = ResolvedValueReader()

    // MARK: - Initializer
    package init() {
        self.init(checker: ResolvedDocumentChecker())
    }

    init(checker: ResolvedDocumentChecker) {
        self.checker = checker
    }

    // MARK: - Public
    package func read(_ text: String) throws -> DisplayList {
        try read(JSONReader().read(text))
    }

    func read(_ value: JSONValue) throws -> DisplayList {
        let root = PlacedJSONValue(value, place: .root, kind: "display list")
        let version = try values.member("displayList", of: root, kind: root.kind)
        let written = version.value.stringValue ?? version.value.written
        guard checker.isReadable(written) else {
            throw EvaluateError.unreadableVersion(
                place: version.place,
                kind: root.kind,
                form: "display list",
                written: written,
                current: checker.current
            )
        }

        let seed = try firstGrain(in: root).map { grain in
            try values.member("seed", of: grain, kind: grain.kind).integer()
        } ?? 0

        return try list(root.object(keys: ["displayList"] + Self.listKeys), seed: seed)
    }

    // MARK: - Private
    // The first `grain` written in the list or in a list nested in it, found before anything is read, since every
    // item takes its seed. What is not of the written shape is left for the reading to stop on.
    private func firstGrain(in list: PlacedJSONValue) -> PlacedJSONValue? {
        let elements = (try? values.member("items", of: list, kind: list.kind).elements()) ?? []

        for element in elements {
            let item = PlacedJSONValue(
                element.value,
                place: element.place,
                kind: element.value.objectValue?["item"]?.stringValue ?? "display item"
            )
            let nested = (try? values.member("source", of: item, kind: item.kind))
                .flatMap { try? values.member("list", of: $0, kind: "display list") }
            let filter = (try? values.member("filter", of: item, kind: item.kind).elements()) ?? []

            if let grain = nested.flatMap(firstGrain) ?? filter.first(where: isGrain) {
                return grain
            }
        }

        return nil
    }

    private func isGrain(_ operation: PlacedJSONValue) -> Bool {
        operation.value.objectValue?["op"]?.stringValue == "grain"
    }

    private func list(
        _ object: PlacedJSONObject,
        seed: Int
    ) throws -> DisplayList {
        DisplayList(
            size: try values.size(object.member("size")),
            background: try values.color(object.member("background")),
            seed: seed,
            items: try object.member("items").elements().map { element in
                try item(element, seed: seed)
            }
        )
    }

    // `item` names what an item draws, which decides the keys it holds besides those every item has.
    private func item(
        _ value: PlacedJSONValue,
        seed: Int
    ) throws -> DisplayItem {
        let name = try values.member("item", of: value, kind: "display item")
            .name(among: Self.itemNames) { Self.itemNames.contains($0) ? $0 : nil }
        let item = try value.object(kind: name, keys: Self.itemKeys + keys(of: name))
        let transform = try item.member("transform").numbers(count: 6)
        let blends = VocabularyTable.blendModes

        return DisplayItem(
            transform: AffineTransform(
                a: transform[0],
                b: transform[1],
                c: transform[2],
                d: transform[3],
                tx: transform[4],
                ty: transform[5]
            ),
            opacity: try item.member("opacity").number(),
            blend: try item.member("blend").name(among: blends) { blends.contains($0) ? $0 : nil },
            mask: try item.member("mask").optional(values.rectangle),
            reveal: try item.member("reveal").optional(values.rectangle),
            content: try content(of: item, name: name, seed: seed),
            origin: try item.member("origin").optional(origin)
        )
    }

    private func keys(of name: String) -> [String] {
        switch name {
        case "picture":
            ["source", "rect", "dest", "filter", "matte", "radius", "border", "shadow"]

        case "path":
            ["geometry", "fill", "stroke", "trim", "shadow"]

        case "glyphs":
            ["size", "runs", "stroke", "background"]

        default:
            ["rect", "filter"]
        }
    }

    private func origin(_ value: PlacedJSONValue) throws -> ItemOrigin {
        let origin = try value.object(keys: ["place", "id", "kind"])

        return ItemOrigin(
            place: try origin.member("place").string(),
            id: try origin.member("id").optional { try $0.string() },
            kind: try origin.member("kind").string()
        )
    }

    private func content(
        of item: PlacedJSONObject,
        name: String,
        seed: Int
    ) throws -> DisplayContent {
        switch name {
        case "picture":
            return .picture(try picture(item, seed: seed))

        case "path":
            return .path(try path(item))

        case "glyphs":
            return .glyphs(try glyphs(item))

        default:
            return .adjust(AdjustItem(
                rectangle: try item.member("rect").optional(values.rectangle),
                filter: try filter(item.member("filter"), seed: seed)
            ))
        }
    }

    private func picture(
        _ item: PlacedJSONObject,
        seed: Int
    ) throws -> PictureItem {
        PictureItem(
            source: try source(item.member("source"), seed: seed),
            rectangle: try item.member("rect").optional(values.rectangle),
            destination: try values.rectangle(item.member("dest")),
            filter: try filter(item.member("filter"), seed: seed),
            matte: try item.member("matte").optional { value in
                let matte = try value.object(keys: ["source", "frame", "progress", "softness", "invert"])

                return PictureMatte(
                    frame: try frame(of: matte, mediaKey: "source"),
                    progress: try matte.member("progress").number(),
                    softness: try matte.member("softness").number(),
                    isInverted: try matte.member("invert").bool()
                )
            },
            radius: try item.member("radius").number(),
            border: try item.member("border").optional { value in
                let border = try value.object(keys: ["width", "color"])

                return MediaBorder(
                    width: try border.member("width").number(),
                    color: try values.color(border.member("color"))
                )
            },
            shadow: try item.member("shadow").optional(shadow)
        )
    }

    private func path(_ item: PlacedJSONObject) throws -> PathItem {
        PathItem(
            geometry: try geometry(item.member("geometry")),
            fill: try item.member("fill").optional(values.color),
            stroke: try item.member("stroke").optional { value in
                let stroke = try value.object(keys: ["width", "color", "join", "cap", "start", "end"])

                return PathStroke(
                    width: try stroke.member("width").number(),
                    color: try values.color(stroke.member("color")),
                    join: try literal(stroke.member("join")),
                    cap: try literal(stroke.member("cap")),
                    start: try literal(stroke.member("start")),
                    end: try literal(stroke.member("end"))
                )
            },
            trim: try trim(item.member("trim")),
            shadow: try item.member("shadow").optional(shadow)
        )
    }

    // One member named by its form: `rect`, `ellipse` or `polyline`, which runs through at least two points.
    private func geometry(_ value: PlacedJSONValue) throws -> PathGeometry {
        let geometry = try value.object(keys: Self.geometryForms)
        let written = Self.geometryForms.filter(geometry.contains)
        guard let name = written.first else {
            throw ModelError.missingKey(place: value.place, kind: value.kind, keys: Self.geometryForms)
        }
        guard written.count == 1 else {
            throw ModelError.conflictingKeys(place: value.place, kind: value.kind, keys: written)
        }

        let form = try geometry.member(name)
        switch name {
        case "rect":
            let rect = try form.object(keys: ["rect", "radius"])

            return .rect(try values.rectangle(rect.member("rect")), radius: try rect.member("radius").number())

        case "ellipse":
            return .ellipse(try values.rectangle(form.object(keys: ["rect"]).member("rect")))

        default:
            let polyline = try form.object(keys: ["points", "closed"])
            let written = try polyline.member("points")
            let points = try written.elements().map(values.point)
            guard points.count >= 2 else {
                throw ModelError.invalidValue(
                    place: written.place,
                    kind: written.kind,
                    reason: "a polyline runs through at least two points, found \(points.count)"
                )
            }

            return .polyline(points, isClosed: try polyline.member("closed").bool())
        }
    }

    // `[a, b]`, each from 0 to 1.
    private func trim(_ value: PlacedJSONValue) throws -> Trim {
        let numbers = try value.numbers(count: 2)
        for (element, number) in zip(try value.elements(), numbers) where !(0...1).contains(number) {
            throw ModelError.invalidValue(
                place: element.place,
                kind: element.kind,
                reason: "a trim runs from 0 to 1, found \(element.value.written)"
            )
        }

        return Trim(start: numbers[0], end: numbers[1])
    }

    private func shadow(_ value: PlacedJSONValue) throws -> DropShadow {
        let shadow = try value.object(keys: ["radius", "offset", "color"])

        return DropShadow(
            radius: try shadow.member("radius").number(),
            offset: try values.point(shadow.member("offset")),
            color: try values.color(shadow.member("color"))
        )
    }

    // A name among the literals a stroke key takes.
    private func literal<Literal: CaseIterable & RawRepresentable>(
        _ value: PlacedJSONValue
    ) throws -> Literal where Literal.RawValue == String {
        try value.name(among: Literal.allCases.map(\.rawValue), Literal.init(rawValue:))
    }

    // `{media, frame}` for a frame of media and `{list}` for a nested list, which takes the seed of the list holding
    // it.
    private func source(
        _ value: PlacedJSONValue,
        seed: Int
    ) throws -> PictureItemSource {
        guard value.value.objectValue?.contains("list") == true else {
            return .media(try frame(of: value.object(keys: ["media", "frame"]), mediaKey: "media"))
        }

        let list = try value.object(keys: ["list"]).member("list").object(kind: "display list", keys: Self.listKeys)

        return .displayList(try self.list(list, seed: seed))
    }

    // A frame index past the media's frames stops, since a role opens an image sequence's frame file by it.
    private func frame(
        of object: PlacedJSONObject,
        mediaKey: String
    ) throws -> MediaFrame {
        let media = try values.media(object.member(mediaKey))
        let frame = try object.member("frame")
        let index = try frame.integer()
        let count = frameCount(of: media)
        guard (0..<count).contains(index) else {
            throw EvaluateError.frameOutOfRange(place: frame.place, kind: frame.kind, frame: index, count: count)
        }

        return MediaFrame(media: media, index: index)
    }

    // An image sequence has a frame per file, a video one per frame time, and a still the one frame 0.
    private func frameCount(of media: PinnedMedia) -> Int {
        switch media.source {
        case let .imageSequence(files):
            files.count

        case .file:
            max(media.frameTimes.count, 1)
        }
    }

    private func glyphs(_ item: PlacedJSONObject) throws -> GlyphsItem {
        GlyphsItem(
            size: try values.size(item.member("size")),
            runs: try values.runs(item.member("runs")),
            stroke: try item.member("stroke").optional { value in
                let stroke = try value.object(keys: ["width", "color"])

                return TextStroke(
                    width: try stroke.member("width").number(),
                    color: try values.color(stroke.member("color"))
                )
            },
            background: try item.member("background").optional { value in
                let background = try value.object(keys: ["rect", "radius", "color"])

                return GlyphBackground(
                    rectangle: try values.rectangle(background.member("rect")),
                    radius: try background.member("radius").number(),
                    color: try values.color(background.member("color"))
                )
            }
        )
    }

    // Every `grain` carries the list's seed, and one with another seed stops.
    private func filter(
        _ value: PlacedJSONValue,
        seed: Int
    ) throws -> [ResolvedFilterOperation] {
        let operations = try values.filter(value, grainKeys: ["seed"])

        for (element, operation) in zip(try value.elements(), operations) {
            guard case .grain = operation else { continue }

            let written = try values.member("seed", of: element, kind: element.kind)
            let number = try written.integer()
            guard number == seed else {
                throw EvaluateError.differentSeed(place: written.place, kind: element.kind, seed: number, listSeed: seed)
            }
        }

        return operations
    }
}
