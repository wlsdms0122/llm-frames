//
//  DisplayListReader.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Reads a display list as `DisplayListWriter` writes it. The version is checked before anything else, and a member
// that is missing or of another type, or a key the writer never writes there, stops naming its place. The list and
// every list nested in it share one seed: the first `grain` written gives it, and a `grain` with another stops. A list
// with no `grain` reads with seed 0, since only `grain` reads the seed. Only the outermost list carries `colorSpace`
// and `peak`, and it carries `items` or, for a frame with motion blur, `samples`: at least two sample lists, each
// differing from the first only in the members `MovesTable` marks. A nested list carries `items` only. A corner pin is
// strictly convex, or, in a sample list and the lists nested in it, four points at [0, 0] (FRAMES-20 Pictures).
package struct DisplayListReader: Sendable {
    // MARK: - Property
    private static let listKeys = ["size", "background", "compositing", "items"]
    private static let outermostKeys = ["size", "background", "colorSpace", "peak", "compositing", "items", "samples"]
    private static let itemKeys = ["kind", "origin", "transform", "opacity", "blend", "mask", "trackMatte", "reveal"]
    private static let itemNames = ["picture", "path", "glyphs", "adjust"]

    private let checker: ResolvedDocumentChecker
    private let values = ResolvedValueReader()
    private let moves = MovesTable()
    // Whether the items read are a sample list's or in a list nested in one.
    private let isInSample: Bool

    // MARK: - Initializer
    package init() {
        self.init(checker: ResolvedDocumentChecker())
    }

    init(checker: ResolvedDocumentChecker) {
        self.init(checker: checker, isInSample: false)
    }

    private init(
        checker: ResolvedDocumentChecker,
        isInSample: Bool
    ) {
        self.checker = checker
        self.isInSample = isInSample
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

        let list = try root.object(keys: ["displayList"] + Self.outermostKeys)
        switch (list.contains("items"), list.contains("samples")) {
        case (true, true):
            throw ModelError.conflictingKeys(place: list.place, kind: list.kind, keys: ["items", "samples"])

        case (false, false):
            throw ModelError.missingKey(place: list.place, kind: list.kind, keys: ["items", "samples"])

        default:
            break
        }

        let seed = try firstGrain(in: root).map { grain in
            try values.member("seed", of: grain, kind: grain.kind).integer()
        } ?? 0

        return try self.list(
            list,
            colorSpace: try list.member("colorSpace").name(among: VocabularyTable.colorSpaces, ColorSpace.init),
            peak: try list.member("peak").optional { try $0.number() },
            seed: seed
        )
    }

    // MARK: - Private
    // The first `grain` written in the list or in a list nested in it, its items or its sample lists in order, found
    // before anything is read, since every item takes its seed. What is not of the written shape is left for the reading
    // to stop on.
    private func firstGrain(in list: PlacedJSONValue) -> PlacedJSONValue? {
        let items = (try? values.member("items", of: list, kind: list.kind).elements()) ?? []
        let samples = (try? values.member("samples", of: list, kind: list.kind).elements()) ?? []
        let elements = items + samples.flatMap { (try? $0.elements()) ?? [] }

        for element in elements {
            let item = PlacedJSONValue(
                element.value,
                place: element.place,
                kind: element.value.objectValue?["kind"]?.stringValue ?? "display item"
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
        operation.value.objectValue?["kind"]?.stringValue == "grain"
    }

    private func list(
        _ object: PlacedJSONObject,
        colorSpace: ColorSpace?,
        peak: Double? = nil,
        seed: Int
    ) throws -> DisplayList {
        let size = try values.size(object.member("size"))
        let background = try values.color(object.member("background"))
        let compositing = try object.member("compositing").name(among: VocabularyTable.compositings, Compositing.init)
        guard let written = object.optionalMember("samples") else {
            return DisplayList(
                size: size,
                background: background,
                colorSpace: colorSpace,
                peak: peak,
                compositing: compositing,
                seed: seed,
                items: try items(object.member("items"), in: size, seed: seed)
            )
        }

        return DisplayList(
            size: size,
            background: background,
            colorSpace: colorSpace,
            peak: peak,
            compositing: compositing,
            seed: seed,
            samples: try samples(written, in: size, seed: seed)
        )
    }

    // `size` is the size of the list that holds the items. A list's `fills` items name the units 0, 1, 2 and on in
    // order, since a title by unit draws one for each unit in reading order.
    private func items(
        _ value: PlacedJSONValue,
        in size: Size,
        seed: Int
    ) throws -> [DisplayItem] {
        let elements = try value.elements()
        let items = try elements.map { element in try item(element, in: size, seed: seed) }
        let fills = zip(elements, items).compactMap { element, item in fillsUnit(of: item).map { (element, $0) } }
        for (expected, (element, unit)) in fills.enumerated() where unit != expected {
            let written = try values.member("unit", of: element, kind: "glyphs")
            throw ModelError.invalidValue(
                place: written.place,
                kind: "glyphs",
                reason: "the list's fills items name the units 0, 1, 2 and on in order, and this one names unit \(unit) "
                    + "in place of \(expected)"
            )
        }

        return items
    }

    // Each sample list is read before they are compared, so a member of another shape stops as it does in `items`.
    private func samples(
        _ value: PlacedJSONValue,
        in size: Size,
        seed: Int
    ) throws -> [[DisplayItem]] {
        let elements = try value.elements()
        guard elements.count >= 2 else {
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "a list with samples holds at least two sample lists, found \(elements.count)"
            )
        }

        let reader = DisplayListReader(checker: checker, isInSample: true)
        let samples = try elements.map { element in try reader.items(element, in: size, seed: seed) }
        for element in elements.dropFirst() {
            if let difference = moves.difference(of: element, from: elements[0]) {
                throw EvaluateError.differentSample(place: difference.place, kind: difference.kind)
            }
        }

        return samples
    }

    // `size` is the size of the list that holds the item.
    private func item(
        _ value: PlacedJSONValue,
        in size: Size,
        seed: Int
    ) throws -> DisplayItem {
        let name = try values.member("kind", of: value, kind: "display item")
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
            ["source", "rect", "dest", "filter", "matte", "radius", "border", "shadow", "cornerPin"]

        case "path":
            ["geometry", "fill", "stroke", "trim", "shadow"]

        case "glyphs":
            ["size", "writingMode", "runs", "layer", "unit", "unitBox", "extent", "background"]

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
        let source = try nestedList(written.object(keys: ["list"]).member("list"), seed: seed)
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
        let picture = PictureItem(
            source: try source(item.member("source"), seed: seed),
            rectangle: try item.member("rect").optional(values.rectangle),
            destination: try values.rectangle(item.member("dest")),
            filter: try filter(item.member("filter"), seed: seed),
            matte: try item.member("matte").optional { value in
                let matte = try value.object(keys: ["source", "frame", "play", "colorSpace", "progress", "softness", "invert"])
                let reading = PictureReading.analysis(colorSpace: try colorSpace(matte.member("colorSpace")))

                return PictureMatte(
                    frame: try frame(of: matte, mediaKey: "source", reading: reading),
                    progress: try matte.member("progress").number(),
                    softness: try matte.member("softness").number(),
                    isInverted: try matte.member("invert").bool()
                )
            },
            radius: try values.cornerRadii(item.member("radius")),
            border: try item.member("border").optional { value in
                let border = try value.object(keys: ["width", "color", "align"])

                return MediaBorder(
                    width: try border.member("width").number(),
                    color: try values.color(border.member("color")),
                    align: try literal(border.member("align"))
                )
            },
            shadow: try item.member("shadow").optional(shadow),
            cornerPin: try item.member("cornerPin").optional(cornerPin)
        )
        // Only a clip's group carries a corner pin, and its source is a nested list (FRAMES-20 Pictures).
        if case .media = picture.source, picture.cornerPin != nil {
            let value = try item.member("cornerPin")
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "a picture of a media frame carries no corner pin"
            )
        }

        return picture
    }

    private func path(_ item: PlacedJSONObject) throws -> PathItem {
        let path = PathItem(
            geometry: try values.geometry(item.member("geometry")),
            fill: try item.member("fill").optional(values.paint),
            stroke: try item.member("stroke").optional { value in
                let stroke = try value.object(
                    keys: ["width", "paint", "align", "join", "cap", "start", "end", "dash", "dashOffset"]
                )

                return PathStroke(
                    width: try stroke.member("width").number(),
                    paint: try values.paint(stroke.member("paint")),
                    align: try literal(stroke.member("align")),
                    join: try literal(stroke.member("join")),
                    cap: try literal(stroke.member("cap")),
                    start: try stroke.member("start").optional(end) ?? .none,
                    end: try stroke.member("end").optional(end) ?? .none,
                    dash: try stroke.member("dash").optional { try $0.numbers() },
                    dashOffset: try stroke.member("dashOffset").number()
                )
            },
            trim: try trim(item.member("trim")),
            shadow: try item.member("shadow").optional(shadow)
        )
        // A stroke on one side of its outline needs a closed outline and no arrowhead (FRAMES-20 Paths).
        if
            let stroke = path.stroke,
            stroke.align != .center,
            !path.isClosed || stroke.start.head != nil || stroke.end.head != nil
        {
            let value = try item.member("stroke")
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "a stroke inside or outside its outline needs a closed outline and no arrowhead"
            )
        }

        return path
    }

    // A stroke's end that draws a head, `null` where it draws none: its head's outline as a closed path in its own
    // units, with a tangent of each kind for each vertex, beside its `length`, `inset` and `scale`, the head keeping
    // every rule of a head preset (FRAMES-11 Heads).
    private func end(_ value: PlacedJSONValue) throws -> StrokeEnd {
        let end = try value.object(keys: ["vertices", "inTangents", "outTangents", "length", "inset", "scale"])
        let vertices = try end.member("vertices").elements().map(values.point)
        let tangents = { (key: String) throws -> [Point] in
            let written = try end.member(key)
            let tangents = try written.elements().map(self.values.point)
            guard tangents.count == vertices.count else {
                throw ModelError.invalidValue(
                    place: written.place,
                    kind: written.kind,
                    reason: "a head has a tangent for each of its \(vertices.count) vertices, found \(tangents.count)"
                )
            }

            return tangents
        }
        let inTangents = try tangents("inTangents")
        let outTangents = try tangents("outTangents")
        let head = StrokeHead(
            outline: vertices.indices.map { index in
                PathVertex(vertex: vertices[index], inTangent: inTangents[index], outTangent: outTangents[index])
            },
            length: try end.member("length").number(),
            inset: try end.member("inset").number()
        )
        if let refusal = head.refusal {
            throw ModelError.invalidValue(place: value.place, kind: value.kind, reason: refusal)
        }

        return StrokeEnd(head: head, scale: try end.member("scale").number())
    }

    // Four points the corners of `dest` go to, a corner pin a display list holds (`Quad.isCornerPin(inSampleList:)`).
    private func cornerPin(_ value: PlacedJSONValue) throws -> Quad {
        let elements = try value.elements()
        guard elements.count == 4 else { throw value.wrongType("a list of 4 points") }

        let corners = try elements.map(values.point)
        let quad = Quad(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3])
        guard quad.isCornerPin(inSampleList: isInSample) else {
            let form = isInSample
                ? "a corner pin in a sample list is a strictly convex quadrilateral or four points at [0, 0]"
                : "a corner pin is a strictly convex quadrilateral"
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "\(form), found \(value.value.written)"
            )
        }

        return quad
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

    // A picture's source by its `kind`: a frame of pinned media, or a nested list.
    private func source(
        _ value: PlacedJSONValue,
        seed: Int
    ) throws -> PictureItemSource {
        let kinds = ["media", "list"]
        let kind = try values.member("kind", of: value, kind: value.kind)
            .name(among: kinds) { kinds.contains($0) ? $0 : nil }

        guard kind == "list" else {
            let source = try value.object(keys: ["kind", "media", "frame", "play", "colorSpace", "targetPeak"])
            let reading = PictureReading.working(
                colorSpace: try colorSpace(source.member("colorSpace")),
                targetPeak: try source.member("targetPeak").optional(targetPeak)
            )

            return .media(try frame(of: source, mediaKey: "media", reading: reading))
        }

        return .displayList(try nestedList(
            value.object(keys: ["kind", "list"]).member("list"),
            seed: seed
        ))
    }

    private func nestedList(
        _ written: PlacedJSONValue,
        seed: Int
    ) throws -> DisplayList {
        guard written.value.objectValue?.contains("samples") != true else {
            throw ModelError.invalidValue(
                place: written.place.appending(key: "samples"),
                kind: "display list",
                reason: "only the outermost list of a frame holds samples"
            )
        }

        let list = try written.object(kind: "display list", keys: Self.listKeys)

        return try self.list(list, colorSpace: nil, seed: seed)
    }

    // A frame index past the media's frames stops, since a role opens an image sequence's frame file by it. A page of a
    // PDF has frame null. A play null is a file read on its own.
    private func frame(
        of object: PlacedJSONObject,
        mediaKey: String,
        reading: PictureReading
    ) throws -> MediaFrame {
        let media = try values.media(object.member(mediaKey))
        let play = try object.member("play").optional { try MediaPlay.place($0.string()) } ?? .file
        let frame = try object.member("frame")
        guard media.page == nil else {
            guard frame.isNull else {
                throw EvaluateError.frameOfPage(place: frame.place, kind: frame.kind, written: frame.value.written)
            }

            return MediaFrame(media: media, index: 0, play: play, reading: reading)
        }

        let index = try frame.integer()
        let count = frameCount(of: media)
        guard (0..<count).contains(index) else {
            throw EvaluateError.frameOutOfRange(place: frame.place, kind: frame.kind, frame: index, count: count)
        }

        return MediaFrame(media: media, index: index, play: play, reading: reading)
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

    // An image sequence has a frame per file, a video one per frame time, and an image and a page the one frame 0.
    private func frameCount(of media: PinnedMedia) -> Int {
        switch media.source {
        case let .imageSequence(files, _):
            files.count

        case let .file(_, frameTimes):
            frameTimes?.count ?? 1

        case .page:
            1
        }
    }

    private func glyphs(_ item: PlacedJSONObject) throws -> GlyphsItem {
        GlyphsItem(
            size: try values.size(item.member("size")),
            writingMode: try literal(item.member("writingMode")),
            runs: try values.drawnRuns(item.member("runs")),
            unit: try unit(of: item),
            extent: try values.rectangle(item.member("extent")),
            background: try item.member("background").optional { value in
                let background = try value.object(keys: ["rect", "radius", "color"])

                return GlyphBackground(
                    rectangle: try values.rectangle(background.member("rect")),
                    radius: try values.cornerRadii(background.member("radius")),
                    color: try values.color(background.member("color"))
                )
            }
        )
    }

    // A unit's item carries its layer, its unit's index and its unit's box, and a title's own item none of them.
    private func unit(of item: PlacedJSONObject) throws -> UnitDrawing? {
        let layer: GlyphLayer? = try item.member("layer").optional { try literal($0) }
        let index = try item.member("unit").optional { value in
            guard let unit = Int(exactly: try value.number()), unit >= 0 else { throw value.wrongType("a unit index") }

            return unit
        }
        let box = try item.member("unitBox").optional { try values.rectangle($0) }
        switch (layer, index, box) {
        case let (layer?, index?, box?):
            return UnitDrawing(layer: layer, index: index, box: box)

        case (nil, nil, nil):
            return nil

        default:
            let found = [("layer", layer != nil), ("unit", index != nil), ("unitBox", box != nil)].filter(\.1).map(\.0)
            throw ModelError.invalidValue(
                place: item.place,
                kind: item.kind,
                reason: "a unit's item carries layer, unit and unitBox, and a title's own item none of them, found only "
                    + found.joined(separator: " and ")
            )
        }
    }

    private func fillsUnit(of item: DisplayItem) -> Int? {
        guard case let .glyphs(glyphs) = item.content, let unit = glyphs.unit, unit.layer == .fills else { return nil }

        return unit.index
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
