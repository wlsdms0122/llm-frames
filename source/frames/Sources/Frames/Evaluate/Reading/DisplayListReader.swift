//
//  DisplayListReader.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Reads a display list as `DisplayListWriter` writes it. The version is checked before anything else, and a member
// that is missing or of another type, or a key the writer never writes there, stops naming its place. The list and
// every list nested in it share one seed: the first `grain` written gives it, and a `grain` with another stops. A list
// with no `grain` reads with seed 0, since only `grain` reads the seed. Only the outermost list carries `colorSpace`.
package struct DisplayListReader: Sendable {
    // MARK: - Property
    private static let listKeys = ["size", "background", "compositing", "items"]
    private static let outermostKeys = ["size", "background", "colorSpace", "peak", "compositing", "items"]
    private static let itemKeys = ["item", "origin", "transform", "opacity", "blend", "mask", "trackMatte", "reveal"]
    private static let itemNames = ["picture", "path", "glyphs", "adjust"]

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

        let list = try root.object(keys: ["displayList"] + Self.outermostKeys)

        return try self.list(
            list,
            colorSpace: try list.member("colorSpace").name(among: VocabularyTable.colorSpaces, ColorSpace.init),
            peak: try list.member("peak").optional { try $0.number() },
            seed: seed
        )
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
            let trackMatte = (try? values.member("trackMatte", of: item, kind: item.kind))
                .flatMap { try? values.member("source", of: $0, kind: "track matte") }
            let entries = (try? values.member("filter", of: item, kind: item.kind).elements()) ?? []
            let filter = entries.flatMap { entry in
                (try? values.member("ops", of: entry, kind: "filter entry").elements()) ?? []
            }
            let grain = trackMatte.flatMap(nestedGrain)
                ?? (try? values.member("source", of: item, kind: item.kind)).flatMap(nestedGrain)
                ?? filter.first(where: isGrain)

            if let grain {
                return grain
            }
        }

        return nil
    }

    private func nestedGrain(in source: PlacedJSONValue) -> PlacedJSONValue? {
        (try? values.member("list", of: source, kind: "display list")).flatMap(firstGrain)
    }

    private func isGrain(_ operation: PlacedJSONValue) -> Bool {
        operation.value.objectValue?["op"]?.stringValue == "grain"
    }

    private func list(
        _ object: PlacedJSONObject,
        colorSpace: ColorSpace?,
        peak: Double? = nil,
        seed: Int
    ) throws -> DisplayList {
        let size = try values.size(object.member("size"))

        return DisplayList(
            size: size,
            background: try values.color(object.member("background")),
            colorSpace: colorSpace,
            peak: peak,
            compositing: try object.member("compositing").name(among: VocabularyTable.compositings, Compositing.init),
            seed: seed,
            items: try object.member("items").elements().map { element in
                try item(element, in: size, seed: seed)
            }
        )
    }

    // `size` is the size of the list that holds the item.
    private func item(
        _ value: PlacedJSONValue,
        in size: Size,
        seed: Int
    ) throws -> DisplayItem {
        let name = try values.member("item", of: value, kind: "display item")
            .name(among: Self.itemNames) { Self.itemNames.contains($0) ? $0 : nil }
        let item = try value.object(kind: name, keys: Self.itemKeys + keys(of: name))
        let blends = VocabularyTable.blendModes

        return DisplayItem(
            transform: try transform(item.member("transform")),
            opacity: try item.member("opacity").number(),
            blend: try item.member("blend").name(among: blends) { blends.contains($0) ? $0 : nil },
            mask: try item.member("mask").optional(masks) ?? [],
            trackMatte: try item.member("trackMatte").optional { try trackMatte($0, in: size, seed: seed) },
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
            ["size", "runs", "layer", "unitBox", "unitGlyphBox", "background"]

        default:
            ["filter"]
        }
    }

    private func transform(_ value: PlacedJSONValue) throws -> AffineTransform {
        AffineTransform(matrix: try value.numbers(count: 6))
    }

    // An item without masks writes `null`, so a list holds at least one.
    private func masks(_ value: PlacedJSONValue) throws -> [ItemMask] {
        let elements = try value.elements()
        guard !elements.isEmpty else {
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "a mask list holds at least one mask, and an item without one has null"
            )
        }

        return try elements.map(mask)
    }

    private func mask(_ value: PlacedJSONValue) throws -> ItemMask {
        let mask = try value.object(keys: ["geometry", "transform", "feather", "invert", "mode"])

        return ItemMask(
            geometry: try values.maskGeometry(mask.member("geometry")),
            transform: try transform(mask.member("transform")),
            feather: try values.maskFeather(mask.member("feather")),
            isInverted: try mask.member("invert").bool(),
            mode: try literal(mask.member("mode"))
        )
    }

    private func trackMatte(
        _ value: PlacedJSONValue,
        in size: Size,
        seed: Int
    ) throws -> ItemTrackMatte {
        let trackMatte = try value.object(keys: ["source", "mode", "invert"])
        let written = try trackMatte.member("source")
        let source = try nestedList(written, seed: seed)
        guard source.size == size else {
            throw EvaluateError.trackMatteSize(place: written.place, kind: written.kind, size: source.size, listSize: size)
        }

        return ItemTrackMatte(
            source: source,
            mode: try literal(trackMatte.member("mode")),
            isInverted: try trackMatte.member("invert").bool()
        )
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
            return .adjust(AdjustItem(filter: try filter(item.member("filter"), seed: seed)))
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
                let matte = try value.object(keys: ["source", "frame", "colorSpace", "progress", "softness", "invert"])
                let frame = try frame(of: matte, mediaKey: "source")

                return PictureMatte(
                    frame: MediaFrame(
                        media: frame.media,
                        index: frame.index,
                        reading: .analysis(colorSpace: try colorSpace(matte.member("colorSpace")))
                    ),
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
            geometry: try values.geometry(item.member("geometry")),
            fill: try item.member("fill").optional(values.paint),
            stroke: try item.member("stroke").optional { value in
                let stroke = try value.object(keys: ["width", "paint", "join", "cap", "start", "end", "dash", "dashOffset"])

                return PathStroke(
                    width: try stroke.member("width").number(),
                    paint: try values.paint(stroke.member("paint")),
                    join: try literal(stroke.member("join")),
                    cap: try literal(stroke.member("cap")),
                    start: try literal(stroke.member("start")),
                    end: try literal(stroke.member("end")),
                    dash: try stroke.member("dash").optional { try $0.numbers() },
                    dashOffset: try stroke.member("dashOffset").number()
                )
            },
            trim: try trim(item.member("trim")),
            shadow: try item.member("shadow").optional(shadow)
        )
    }

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

    private func literal<Literal: CaseIterable & RawRepresentable>(
        _ value: PlacedJSONValue
    ) throws -> Literal where Literal.RawValue == String {
        try value.name(among: Literal.allCases.map(\.rawValue), Literal.init(rawValue:))
    }

    private func source(
        _ value: PlacedJSONValue,
        seed: Int
    ) throws -> PictureItemSource {
        guard value.value.objectValue?.contains("list") == true else {
            let source = try value.object(keys: ["media", "frame", "colorSpace", "targetPeak"])
            let frame = try frame(of: source, mediaKey: "media")

            return .media(MediaFrame(
                media: frame.media,
                index: frame.index,
                reading: .working(
                    colorSpace: try colorSpace(source.member("colorSpace")),
                    targetPeak: try source.member("targetPeak").optional(targetPeak)
                )
            ))
        }

        return .displayList(try nestedList(value, seed: seed))
    }

    private func nestedList(
        _ value: PlacedJSONValue,
        seed: Int
    ) throws -> DisplayList {
        let list = try value.object(keys: ["list"]).member("list").object(kind: "display list", keys: Self.listKeys)

        return try self.list(list, colorSpace: nil, seed: seed)
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

    // The space a picture is read in, null where its file's tags apply.
    private func colorSpace(_ value: PlacedJSONValue) throws -> ColorSpace? {
        try value.optional { value in try value.name(among: VocabularyTable.colorSpaces, ColorSpace.init) }
    }

    // The peak an HDR picture is tone mapped to, in cd/m², above 0.
    private func targetPeak(_ value: PlacedJSONValue) throws -> Double {
        let peak = try value.number()
        guard peak > 0 else {
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "a target peak is above 0 cd/m², found \(value.value.written)"
            )
        }

        return peak
    }

    // An image sequence has a frame per file, a video one per frame time, and a still the one frame 0.
    private func frameCount(of media: PinnedMedia) -> Int {
        switch media.source {
        case let .imageSequence(files):
            files.count

        case .file, .page:
            max(media.frameTimes.count, 1)
        }
    }

    private func glyphs(_ item: PlacedJSONObject) throws -> GlyphsItem {
        GlyphsItem(
            size: try values.size(item.member("size")),
            runs: try values.drawnRuns(item.member("runs")),
            layer: try item.member("layer").optional { try literal($0) },
            unitBox: try item.member("unitBox").optional { try values.rectangle($0) },
            unitGlyphBox: try item.member("unitGlyphBox").optional { try values.rectangle($0) },
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

    private func filter(
        _ value: PlacedJSONValue,
        seed: Int
    ) throws -> [FilterEntry] {
        let entries = try values.filter(value, grainKeys: ["seed"])
        let written = try value.elements().flatMap { try $0.object(keys: ["ops", "mix"]).member("ops").elements() }

        for (element, operation) in zip(written, entries.flatMap(\.operations)) {
            guard case .grain = operation else { continue }

            let written = try values.member("seed", of: element, kind: element.kind)
            let number = try written.integer()
            guard number == seed else {
                throw EvaluateError.differentSeed(place: written.place, kind: element.kind, seed: number, listSeed: seed)
            }
        }

        return entries
    }
}
