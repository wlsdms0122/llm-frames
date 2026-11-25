//
//  ResolvedValueReader.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads the values a resolved sequence, a display list and a mix plan share, as `ResolvedValueWriter` writes them:
// geometry, colours, paints, eases, keyframe lists, filter operations, spans, animations, shaped text, and pinned
// files.
struct ResolvedValueReader: Sendable {
    // MARK: - Property
    // The keys of pinned media, which an object holding it carries beside its own.
    static let mediaKeys = ["file", "sha256", "page", "imageSequence", "frames"]
    static let spanKeys = ["ease", "revealFrom", "keys"]
    static let geometryForms = ["rect", "ellipse", "path"]

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // A member of an object read before its keys are checked, since the member decides which keys it holds.
    func member(
        _ key: String,
        of value: PlacedJSONValue,
        kind: String
    ) throws -> PlacedJSONValue {
        guard let object = value.value.objectValue else {
            throw ModelError.wrongType(place: value.place, kind: kind, expected: "an object", found: value.finding)
        }

        return try PlacedJSONObject(object, place: value.place, kind: kind).member(key)
    }

    // The kind a resolved document or a document nested in one names.
    func documentKind(_ value: PlacedJSONValue) throws -> String {
        let kinds = ["sequence"]

        return try member("kind", of: value, kind: value.kind).name(among: kinds) { kinds.contains($0) ? $0 : nil }
    }

    func pinned(_ object: PlacedJSONObject) throws -> PinnedFile {
        PinnedFile(path: try object.member("file").string(), sha256: try object.member("sha256").string())
    }

    // An image sequence is its frame files in order, a page of a PDF its file with its number from 1, and the frame
    // times are written only for a video or image sequence.
    func media(_ object: PlacedJSONObject) throws -> PinnedMedia {
        let source: PinnedSource = if object.contains("imageSequence") {
            .imageSequence(try object.member("imageSequence").elements().map { element in
                try pinned(element.object(keys: ["file", "sha256"]))
            })
        } else if let page = object.optionalMember("page") {
            .page(try pinned(object), page: try pageNumber(page))
        } else {
            .file(try pinned(object))
        }

        return PinnedMedia(source: source, frameTimes: try object.optionalMember("frames")?.numbers() ?? [])
    }

    func media(_ value: PlacedJSONValue) throws -> PinnedMedia {
        try media(value.object(keys: Self.mediaKeys))
    }

    func rectangle(_ value: PlacedJSONValue) throws -> Rectangle {
        let numbers = try value.numbers(count: 4)

        return Rectangle(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    func point(_ value: PlacedJSONValue) throws -> Point {
        let numbers = try value.numbers(count: 2)

        return Point(x: numbers[0], y: numbers[1])
    }

    // An area as numbers or a clip area `{clip, padding}`.
    func geometryArea(_ value: PlacedJSONValue) throws -> GeometryArea {
        guard value.value.objectValue != nil else { return .rectangle(try rectangle(value)) }

        return .clip(try clipArea(value))
    }

    // A point as numbers or a placement name.
    func geometryAnchor(_ value: PlacedJSONValue) throws -> GeometryAnchor {
        guard value.value.stringValue != nil else { return .point(try point(value)) }

        let names = VocabularyTable.placementNames
        return .named(try value.name(among: names) { names.contains($0) ? $0 : nil })
    }

    // A point as numbers or a point of a clip area `{area, point}`.
    func geometryPoint(_ value: PlacedJSONValue) throws -> GeometryPoint {
        guard value.value.objectValue != nil else { return .point(try point(value)) }

        let object = try value.object(keys: ["area", "point"])
        let names = VocabularyTable.placementNames
        let name = try object.member("point").name(among: names) { names.contains($0) ? $0 : nil }
        return .clip(try clipArea(object.member("area")), point: name)
    }

    // Four corners, top left, top right, bottom right and bottom left.
    func quad(_ value: PlacedJSONValue) throws -> Quad {
        let corners = try value.elements()
        guard corners.count == 4 else {
            throw ModelError.wrongType(
                place: value.place,
                kind: value.kind,
                expected: "a list of 4 points",
                found: value.finding
            )
        }
        let points = try corners.map(point)

        return Quad(topLeft: points[0], topRight: points[1], bottomRight: points[2], bottomLeft: points[3])
    }

    // A path item's fill or stroke paint: a colour, or a gradient as one member named by its kind, `linear` or
    // `radial` of a radius 0 or more, its stops at least two `[offset, colour]` with offsets from 0 to 1 in order.
    func paint(_ value: PlacedJSONValue) throws -> Paint {
        guard value.value.objectValue != nil else { return .color(try color(value)) }

        let forms = ["linear", "radial"]
        let paint = try value.object(keys: forms)
        let written = forms.filter(paint.contains)
        guard let name = written.first else {
            throw ModelError.missingKey(place: value.place, kind: value.kind, keys: forms)
        }
        guard written.count == 1 else {
            throw ModelError.conflictingKeys(place: value.place, kind: value.kind, keys: written)
        }

        let form = try paint.member(name)
        let body = try form.object(keys: name == "linear" ? ["from", "to", "stops"] : ["center", "radius", "stops"])
        let shape: GradientShape
        if name == "linear" {
            shape = .linear(from: try point(body.member("from")), to: try point(body.member("to")))
        } else {
            let radius = try body.member("radius")
            guard try radius.number() >= 0 else {
                throw ModelError.invalidValue(place: radius.place, kind: radius.kind, reason: "a radius is 0 or more")
            }
            shape = .radial(center: try point(body.member("center")), radius: try radius.number())
        }

        let list = try body.member("stops")
        let stops = try list.elements().map { element in
            let pair = try element.elements()
            guard pair.count == 2 else { throw element.wrongType("[offset, colour]") }

            return GradientStop(offset: try pair[0].number(), color: try color(pair[1]))
        }
        let offsets = stops.map(\.offset)
        guard
            stops.count >= 2,
            offsets.allSatisfy({ (0...1).contains($0) }),
            zip(offsets, offsets.dropFirst()).allSatisfy({ $0 <= $1 })
        else {
            throw ModelError.invalidValue(
                place: list.place,
                kind: list.kind,
                reason: "a gradient has at least two stops, their offsets from 0 to 1 and in order"
            )
        }

        return .gradient(Gradient(shape: shape, stops: stops))
    }

    // A path item's or a mask's geometry, one member named by its form: `rect`, `ellipse` or `path`, which runs
    // through at least two vertices, with an in and an out tangent for each.
    func geometry(_ value: PlacedJSONValue) throws -> PathGeometry {
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

            return .rect(try rectangle(rect.member("rect")), radius: try cornerRadii(rect.member("radius")))

        case "ellipse":
            return .ellipse(try rectangle(form.object(keys: ["rect"]).member("rect")))

        default:
            let path = try form.object(keys: ["vertices", "inTangents", "outTangents", "closed"])
            let written = try path.member("vertices")
            let vertices = try written.elements().map(point)
            guard vertices.count >= 2 else {
                throw ModelError.invalidValue(
                    place: written.place,
                    kind: written.kind,
                    reason: "a path runs through at least two vertices, found \(vertices.count)"
                )
            }

            let tangents = { (key: String) throws -> [Point] in
                let written = try path.member(key)
                let tangents = try written.elements().map(self.point)
                guard tangents.count == vertices.count else {
                    throw ModelError.invalidValue(
                        place: written.place,
                        kind: written.kind,
                        reason: "a path has a tangent for each of its \(vertices.count) vertices, found \(tangents.count)"
                    )
                }

                return tangents
            }
            let inTangents = try tangents("inTangents")
            let outTangents = try tangents("outTangents")

            return .path(
                vertices.indices.map { index in
                    PathVertex(vertex: vertices[index], inTangent: inTangents[index], outTangent: outTangents[index])
                },
                isClosed: try path.member("closed").bool()
            )
        }
    }

    // A mask's geometry, in a resolved document and a display list: a path mask is a closed path.
    func maskGeometry(_ value: PlacedJSONValue) throws -> PathGeometry {
        let geometry = try geometry(value)
        if case let .path(_, isClosed) = geometry, !isClosed {
            throw ModelError.invalidValue(place: value.place, kind: value.kind, reason: "a path mask is a closed path")
        }

        return geometry
    }

    // A mask's feather, in a resolved document and a display list: 0 or more.
    func maskFeather(_ value: PlacedJSONValue) throws -> Double {
        let feather = try value.number()
        guard feather >= 0 else {
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "a feather is 0 or more, found \(value.value.written)"
            )
        }

        return feather
    }

    // A clip's masks: `null`, or a list of at least one mask.
    func masks(_ value: PlacedJSONValue) throws -> [ResolvedMask]? {
        try value.optional { list in
            let elements = try list.elements()
            guard !elements.isEmpty else {
                throw ModelError.invalidValue(
                    place: list.place,
                    kind: list.kind,
                    reason: "a mask list holds at least one mask, and a clip without one has null"
                )
            }

            return try elements.map(mask)
        }
    }

    func size(_ value: PlacedJSONValue) throws -> Size {
        let numbers = try value.numbers(count: 2)

        return Size(width: numbers[0], height: numbers[1])
    }

    func range(_ value: PlacedJSONValue) throws -> TimeRange {
        let numbers = try value.numbers(count: 2)

        return TimeRange(start: numbers[0], end: numbers[1])
    }

    // `color(srgb r g b / a)`, the one form a resolved document and a display list write a colour in.
    func color(_ value: PlacedJSONValue) throws -> Color {
        guard let color = Color(resolvedForm: try value.string()) else {
            throw value.wrongType("a colour as color(srgb r g b / a)")
        }

        return color
    }

    func ease(_ value: PlacedJSONValue) throws -> Ease {
        guard let ease = Ease(value: value.value) else { throw value.wrongType("an ease name, [x1, y1, x2, y2] or {\"kind\": \"spring\", \"bounce\": b}") }

        return ease
    }

    func keyframes<Value: Equatable & Sendable>(
        _ value: PlacedJSONValue,
        read: (PlacedJSONValue) throws -> Value
    ) throws -> [Keyframe<Value>] {
        try value.elements().map { element in
            let keyframe = try element.object(keys: ["at", "value", "ease"])

            return Keyframe(
                at: try keyframe.member("at").number(),
                value: try read(keyframe.member("value")),
                ease: try ease(keyframe.member("ease"))
            )
        }
    }

    // A followed value of a tracked clip is a keyframe list, or its value where it is true on the track's frame
    // (FRAMES-19 Timed values). A keyframe list is a list of objects that hold `at`, and no value of such a leaf is one.
    // A path shape's vertex, `{vertex, inTangent, outTangent}`, each a value a track can carry.
    func vertex(_ value: PlacedJSONValue) throws -> PathVertex<FollowedValue<GeometryPoint>, FollowedValue<Point>> {
        let vertex = try value.object(keys: ["vertex", "inTangent", "outTangent"])

        return PathVertex(
            vertex: try followedKeyframes(vertex.member("vertex"), read: geometryPoint),
            inTangent: try followedKeyframes(vertex.member("inTangent"), read: point),
            outTangent: try followedKeyframes(vertex.member("outTangent"), read: point)
        )
    }

    func followedKeyframes<Value: Equatable & Sendable>(
        _ value: PlacedJSONValue,
        read: (PlacedJSONValue) throws -> Value
    ) throws -> FollowedValue<Value> {
        guard value.value.arrayValue?.first?.objectValue?.contains("at") == true else {
            return .onTrackFrame(try read(value))
        }

        return .keyframes(try keyframes(value, read: read))
    }

    func numbers(_ value: PlacedJSONValue) throws -> [Keyframe<Double>] {
        try keyframes(value) { try $0.number() }
    }

    func followedNumbers(_ value: PlacedJSONValue) throws -> FollowedValue<Double> {
        try followedKeyframes(value) { try $0.number() }
    }

    // Corner radii, written as their four radii (FRAMES-20).
    func cornerRadii(_ value: PlacedJSONValue) throws -> CornerRadii {
        guard
            let elements = value.value.arrayValue,
            case let numbers = elements.compactMap(\.numberValue),
            numbers.count == elements.count,
            let radii = CornerRadii(values: numbers)
        else {
            throw value.wrongType("a list of 4 numbers")
        }

        return radii
    }

    func scales(_ value: PlacedJSONValue) throws -> [Keyframe<Scale>] {
        try keyframes(value) { element in
            let factors = try element.numbers(count: 2)

            return Scale(x: factors[0], y: factors[1])
        }
    }

    func crops(_ value: PlacedJSONValue) throws -> FollowedValue<Crop> {
        try followedKeyframes(value) { Crop(try rectangle($0)) }
    }

    // A timed value as the writer writes it, read by its structure: `null` is `off`, a timed leaf a keyframe list, and
    // a name, a boolean or a file its value. A form is the colour form where its value is not an object of one name.
    // `kind` names the entry an object is, which its stops name.
    func timed(
        _ value: PlacedJSONValue,
        as structure: ValueStructure,
        kind: String? = nil
    ) throws -> TimedValue {
        guard !value.isNull else { return .off }

        switch structure {
        case let .leaf(leaf) where leaf.isTimed:
            if case let .numbers(count) = leaf.form, value.value.arrayValue?.first?.arrayValue != nil {
                let elements = try value.elements()
                guard elements.count == count else { throw value.wrongType("a list of \(count) keyframe lists") }

                return .list(try elements.map { element in
                    .track(try keyframes(element) { try self.leaf($0, as: .number(leaf.domain)) })
                })
            }

            return .track(try keyframes(value) { try self.leaf($0, as: leaf) })

        case let .leaf(leaf):
            if let names = leaf.names {
                _ = try value.name(among: names) { names.contains($0) ? $0 : nil }
            }
            return .fixed(value.value)

        case let .choice(_, forms, _) where !forms.isEmpty:
            return try choice(value, forms: forms, as: structure, kind: kind)

        case .anyValue, .choice:
            return .fixed(value.value)

        case let .object(object):
            let members = try value.object(kind: kind, keys: object.keys.map(\.name))
            return .object(try object.keys.compactMap { key in
                try members.optionalMember(key.name).map { member in
                    TimedMember(key: key.name, value: try timed(member, as: key.structure))
                }
            })

        case let .map(element):
            let members = try value.object(keys: value.value.objectValue?.keys ?? [])
            return .object(try members.object.keys.map { key in
                TimedMember(key: key, value: try timed(members.member(key), as: element))
            })

        case let .list(element):
            return .list(try value.elements().map { try timed($0, as: element) })

        case let .tuple(structures):
            let elements = try value.elements()
            guard elements.count == structures.count else { throw value.wrongType("a list of \(structures.count) values") }

            return .list(try zip(elements, structures).map { try timed($0, as: $1) })

        case let .forms(forms):
            if let object = value.value.objectValue, object.members.count == 1,
                let form = forms.first(where: { $0.name == object.members[0].key }) {
                let body = try value.object(keys: [form.name]).member(form.name)
                return .form(form.name, try timed(body, as: form.structure))
            }
            guard let form = forms.first(where: { $0.name == ValueStructure.colorForm }) else {
                throw value.wrongType("one of the forms \(forms.map(\.name).joined(separator: ", "))")
            }

            return .form(form.name, try timed(value, as: form.structure))
        }
    }

    // A shape's stroke as a timed value, each end `null` or its head's values beside its `scale`, the head keeping every
    // rule of a head preset (FRAMES-11 Heads).
    func stroke(_ value: PlacedJSONValue) throws -> TimedValue {
        let stroke = try timed(value, as: LookStructureTable.resolvedStroke, kind: "stroke")
        guard !value.isNull else { return stroke }

        let keys = ["color", "gradient", "width", "align", "join", "cap", "start", "end", "dash", "dashOffset"]
        let members = try value.object(kind: "stroke", keys: keys)
        for key in ["start", "end"] {
            guard let end = members.optionalMember(key), !end.isNull else { continue }

            guard let head = StrokeHead(written: end.value) else {
                throw ModelError.invalidValue(
                    place: end.place,
                    kind: end.kind,
                    reason: "a stroke's end is null or its head's points, length and inset beside its scale"
                )
            }
            if let refusal = head.refusal {
                throw ModelError.invalidValue(place: end.place, kind: end.kind, reason: refusal)
            }
        }

        return stroke
    }

    // A form of a choice as the writer writes it: its form key naming it, beside the keys of its body.
    private func choice(
        _ value: PlacedJSONValue,
        forms: [(name: String, structure: ValueStructure)],
        as structure: ValueStructure,
        kind: String?
    ) throws -> TimedValue {
        let object = try value.object(kind: kind, keys: structure.formKeys + forms.flatMap { form in
            if case let .object(body) = form.structure { body.keys.map(\.name) } else { [String]() }
        })
        let prefix = structure.formKeys.first(where: object.object.contains) ?? structure.formKeys[0]
        let names = forms.map(\.name).filter { $0.hasPrefix(prefix + ":") }.map { String($0.dropFirst(prefix.count + 1)) }
        let name = try object.member(prefix).name(among: names) { names.contains($0) ? $0 : nil }
        guard let form = forms.first(where: { $0.name == prefix + ":" + name }), case let .object(body) = form.structure
        else {
            return .fixed(value.value)
        }

        let members = try value.object(kind: kind, keys: [prefix] + body.keys.map(\.name))
        return .form(form.name, .object(try body.keys.compactMap { key in
            try members.optionalMember(key.name).map { TimedMember(key: key.name, value: try timed($0, as: key.structure)) }
        }))
    }

    // A display list's filter, its entries `{ops, mix}`. `grainKeys` are the keys a `grain` may hold besides its
    // values: a display list's `seed`, which its reader reads.
    func filter(
        _ value: PlacedJSONValue,
        grainKeys: [String] = []
    ) throws -> [FilterEntry] {
        try value.elements().map { element in
            let entry = try element.object(keys: ["ops", "mix"])
            let mix = try entry.member("mix").number()
            guard (0...1).contains(mix) else { throw try entry.member("mix").wrongType("a number from 0 to 1") }

            return FilterEntry(
                operations: try entry.member("ops").elements().map { try operation($0, grainKeys: grainKeys) },
                mix: mix
            )
        }
    }

    func span(_ object: PlacedJSONObject) throws -> Span {
        let properties = MotionProperty.allCases.map(\.rawValue)

        return Span(
            ease: try ease(object.member("ease")),
            revealFrom: try object.member("revealFrom").name(among: ["left", "right", "top", "bottom"], RevealEdge.init),
            keys: try object.member("keys").elements().map { element in
                let key = try element.object(keys: ["t"] + properties)
                let values = try MotionProperty.allCases.reduce(into: [MotionProperty: Double]()) { values, property in
                    values[property] = try key.optionalMember(property.rawValue)?.number()
                }

                return SpanKey(t: try key.member("t").number(), values: values)
            }
        )
    }

    func span(_ value: PlacedJSONValue) throws -> Span {
        try span(value.object(keys: Self.spanKeys))
    }

    // An entrance and an exit by their `seconds`, a loop by its `period`, each `null` when it takes none, and `by`,
    // `stagger` and `order` all `null` or all given.
    func animation(_ value: PlacedJSONValue) throws -> ResolvedAnimation {
        let animation = try value.object(keys: ["entrance", "loop", "exit", "by", "stagger", "order"])
        let span = { (key: String, length: String) throws -> AnimationSpan? in
            try animation.member(key).optional { value in
                let span = try value.object(keys: [length] + Self.spanKeys)

                return AnimationSpan(length: try span.member(length).number(), span: try self.span(span))
            }
        }

        return ResolvedAnimation(
            entrance: try span("entrance", "seconds"),
            loop: try span("loop", "period"),
            exit: try span("exit", "seconds"),
            units: try units(of: animation)
        )
    }

    func text(_ value: PlacedJSONValue) throws -> ResolvedText {
        let text = try value.object(keys: [
            "size", "textBox", "width", "background", "writingMode", "direction", "align", "lineHeight", "text", "words",
            "lines", "units", "runs"
        ])
        let writingModes = WritingMode.allCases.map(\.rawValue)
        let directions = TextDirection.allCases.map(\.rawValue)
        let alignments = [TextAlignment.left, .center, .right].map(\.rawValue)
        let length = ValueStructure.leaf(.length(.any))
        let writingMode = try text.member("writingMode").name(among: writingModes, WritingMode.init(rawValue:))
        let written = try text.member("text").string()
        let scalarCount = written.unicodeScalars.count
        let runs = try runs(text.member("runs"))
        let glyphCounts = runs.map(\.glyphs.count)
        let lines = try text.member("lines").elements().map { element in
            let line = try element.object(keys: ["width", "baseline", "ascent", "descent", "range", "clusters", "hanging"])

            return PlacedLine(
                width: try line.member("width").number(),
                baseline: try line.member("baseline").number(),
                ascent: try line.member("ascent").number(),
                descent: try line.member("descent").number(),
                range: try scalarRange(line.member("range"), in: scalarCount),
                clusters: try line.member("clusters").elements().map {
                    try cluster($0, glyphCounts: glyphCounts, scalarCount: scalarCount)
                },
                hanging: try line.member("hanging").elements().map {
                    try cluster($0, glyphCounts: glyphCounts, scalarCount: scalarCount)
                }
            )
        }
        for (index, line) in lines.enumerated() {
            let ranges = (line.clusters + line.hanging).map(\.range)
            guard zip(ranges, ranges.dropFirst()).allSatisfy({ $0.upperBound <= $1.lowerBound }) else {
                throw ModelError.invalidValue(
                    place: value.place,
                    kind: value.kind,
                    reason: "line \(index)'s clusters do not go up along the text"
                )
            }
            guard pensFollow(on: line, runs: runs, writingMode: writingMode) else {
                throw ModelError.invalidValue(
                    place: value.place,
                    kind: value.kind,
                    reason: "line \(index)'s pen positions do not follow its clusters' advances, its runs' static tracking and its width"
                )
            }
        }

        return ResolvedText(
            size: try size(text.member("size")),
            textBox: try rectangle(text.member("textBox")),
            width: try text.member("width").optional { try $0.number() },
            background: try text.member("background").optional { value in
                let background = try value.object(keys: ["color", "padding", "radius"])

                return ResolvedBackground(
                    color: try timed(background.member("color"), as: .leaf(.color)),
                    padding: try timed(background.member("padding"), as: .leaf(.lengths(count: 2, domain: .nonNegative))),
                    radius: try timed(background.member("radius"), as: LookStructureTable.radius)
                )
            },
            writingMode: writingMode,
            direction: try text.member("direction").name(among: directions, TextDirection.init(rawValue:)),
            align: try text.member("align").name(among: alignments, TextAlignment.init(rawValue:)),
            lineHeight: try timed(text.member("lineHeight"), as: length),
            text: written,
            words: try text.member("words").elements().map { try scalarRange($0, in: scalarCount) },
            lines: lines,
            units: try text.member("units").optional { value in
                try value.elements().map { element in
                    let unit = try element.object(keys: ["box", "glyphBox", "characters", "hangingLines", "parts"])

                    return PlacedUnit(
                        characters: try characters(unit.member("characters"), in: lines),
                        hangingLines: try unit.member("hangingLines").elements().map { element in
                            guard let line = Int(exactly: try element.number()), lines.indices.contains(line) else {
                                throw element.wrongType("a line index")
                            }

                            return line
                        },
                        lines: lines,
                        glyphCounts: glyphCounts,
                        glyphBox: try rectangle(unit.member("glyphBox")),
                        box: try rectangle(unit.member("box")),
                        parts: try unit.member("parts").elements().map { try unitPart($0, in: runs) }
                    )
                }
            },
            runs: runs
        )
    }

    func runs(_ value: PlacedJSONValue) throws -> [ResolvedGlyphRun] {
        try value.elements().map(run)
    }

    func drawnRuns(_ value: PlacedJSONValue) throws -> [DrawnGlyphRun] {
        try value.elements().map(drawnRun)
    }

    // MARK: - Private
    private func clipArea(_ value: PlacedJSONValue) throws -> ClipArea {
        let object = try value.object(keys: ["clip", "padding"])
        return ClipArea(clip: try object.member("clip").string(), padding: try object.member("padding").number())
    }

    private func leaf(
        _ value: PlacedJSONValue,
        as kind: LeafKind
    ) throws -> LeafValue {
        switch kind.form {
        case .color:
            .color(try color(value))

        case let .numbers(count):
            .numbers(try value.numbers(count: count))

        case .corners:
            .numbers(try cornerRadii(value).values)

        case .number, .name, .boolean, .file, .staticNumber:
            .number(try value.number())
        }
    }

    private func mask(_ value: PlacedJSONValue) throws -> ResolvedMask {
        let mask = try value.object(kind: "mask", keys: ["geometry", "feather", "invert", "mode"])

        return ResolvedMask(
            geometry: try timedMaskGeometry(mask.member("geometry")),
            feather: try keyframes(mask.member("feather"), read: maskFeather),
            isInverted: try mask.member("invert").bool(),
            mode: try mask.member("mode").name(among: MaskMode.allCases.map(\.rawValue), MaskMode.init(rawValue:))
        )
    }

    // A resolved mask's geometry, one member named by its form, each number a keyframe list: a rect or an ellipse by
    // its `rect` or its box `width`, `height` and `position`, and a path as a closed path through at least two
    // vertices, with an in and an out tangent for each.
    private func timedMaskGeometry(_ value: PlacedJSONValue) throws -> ResolvedMaskGeometry {
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
            let rect = try form.object(keys: ["rect", "width", "height", "position", "radius"])
            return .rect(try maskRectangle(rect), radius: try followedKeyframes(rect.member("radius"), read: cornerRadii))

        case "ellipse":
            return .ellipse(try maskRectangle(form.object(keys: ["rect", "width", "height", "position"])))

        default:
            let path = try form.object(keys: ["vertices", "inTangents", "outTangents", "closed"])
            let vertices = try path.member("vertices").elements().map { try followedKeyframes($0, read: geometryPoint) }
            let inTangents = try path.member("inTangents").elements().map { try followedKeyframes($0, read: point) }
            let outTangents = try path.member("outTangents").elements().map { try followedKeyframes($0, read: point) }
            guard
                try path.member("closed").bool(),
                vertices.count >= 2,
                inTangents.count == vertices.count,
                outTangents.count == vertices.count
            else {
                throw ModelError.invalidValue(
                    place: value.place,
                    kind: value.kind,
                    reason: "a path mask is a closed path through at least two vertices, with an in and an out tangent "
                        + "for each"
                )
            }

            return .path(vertices.indices.map { index in
                PathVertex(vertex: vertices[index], inTangent: inTangents[index], outTangent: outTangents[index])
            })
        }
    }

    private func maskRectangle(_ object: PlacedJSONObject) throws -> ResolvedMaskRectangle {
        if object.contains("rect") {
            if let box = ["width", "height", "position"].first(where: object.contains) {
                throw ModelError.conflictingKeys(place: object.place, kind: object.kind, keys: ["rect", box])
            }

            return .area(try followedKeyframes(object.member("rect"), read: geometryArea))
        }

        return .box(
            width: try followedNumbers(object.member("width")),
            height: try followedNumbers(object.member("height")),
            position: try followedKeyframes(object.member("position"), read: geometryPoint)
        )
    }

    private func run(_ value: PlacedJSONValue) throws -> ResolvedGlyphRun {
        let run = try value.object(keys: [
            "source", "file", "sha256", "face", "size", "color", "stroke", "baselineShift", "sideways", "horizontalScale",
            "staticTracking", "tracking", "highlight", "underline", "glyphs"
        ])
        let length = ValueStructure.leaf(.length(.any))

        guard let source = Int(exactly: try run.member("source").number()), source >= 0 else {
            throw try run.member("source").wrongType("a run index")
        }

        return ResolvedGlyphRun(
            source: source,
            font: try pinned(run),
            face: try run.member("face").string(),
            size: try run.member("size").number(),
            color: try timed(run.member("color"), as: .leaf(.color)),
            stroke: try timed(run.member("stroke"), as: LookStructureTable.textStroke, kind: "stroke"),
            baselineShift: try timed(run.member("baselineShift"), as: length),
            isSideways: try run.member("sideways").bool(),
            horizontalScale: try run.member("horizontalScale").number(),
            staticTracking: try run.member("staticTracking").number(),
            tracking: try timed(run.member("tracking"), as: length),
            highlight: try run.member("highlight").optional { value in
                let highlight = try value.object(kind: "highlight", keys: ["color", "padding", "radius", "rects"])

                return ResolvedHighlight(
                    color: try timed(highlight.member("color"), as: .leaf(.color)),
                    padding: try timed(highlight.member("padding"), as: .leaf(.lengths(count: 2, domain: .nonNegative))),
                    radius: try timed(highlight.member("radius"), as: LookStructureTable.radius),
                    rects: try highlight.member("rects").elements().map(rectangle)
                )
            },
            underline: try run.member("underline").optional { value in
                let underline = try value.object(kind: "underline", keys: ["color", "width", "offset", "rects"])

                return ResolvedUnderline(
                    color: try timed(underline.member("color"), as: .leaf(.color)),
                    width: try timed(underline.member("width"), as: length),
                    offset: try timed(underline.member("offset"), as: length),
                    rects: try underline.member("rects").elements().map { element in
                        let numbers = try element.numbers(count: 3)

                        return UnderlinePiece(x: numbers[0], y: numbers[1], width: numbers[2])
                    }
                )
            },
            glyphs: try run.member("glyphs").elements().map { element in
                let numbers = try element.numbers(count: 5)
                guard let id = UInt16(exactly: numbers[0]) else {
                    throw element.wrongType("[glyph id, x, y, dx, dy] with a glyph id from 0 to 65535")
                }

                return PositionedGlyph(
                    id: Int(id),
                    x: numbers[1],
                    y: numbers[2],
                    placementOffset: Point(x: numbers[3], y: numbers[4])
                )
            }
        )
    }

    private func drawnRun(_ value: PlacedJSONValue) throws -> DrawnGlyphRun {
        let run = try value.object(keys: [
            "file", "sha256", "face", "size", "sideways", "horizontalScale", "color", "stroke", "highlight", "underline",
            "glyphs"
        ])

        return DrawnGlyphRun(
            font: try pinned(run),
            face: try run.member("face").string(),
            size: try run.member("size").number(),
            isSideways: try run.member("sideways").bool(),
            horizontalScale: try run.member("horizontalScale").number(),
            color: try color(run.member("color")),
            stroke: try run.member("stroke").optional { value in
                let stroke = try value.object(keys: ["width", "color"])

                return TextStroke(width: try stroke.member("width").number(), color: try color(stroke.member("color")))
            },
            highlight: try run.member("highlight").optional { value in
                let highlight = try value.object(keys: ["rects", "radius", "color", "bands"])
                let rects = try highlight.member("rects").elements().map(rectangle)

                return DrawnHighlight(
                    rects: rects,
                    radius: try cornerRadii(highlight.member("radius")),
                    color: try color(highlight.member("color")),
                    bands: try bands(highlight.member("bands"), count: rects.count)
                )
            },
            underline: try run.member("underline").optional { value in
                let underline = try value.object(keys: ["rects", "color", "bands"])
                let rects = try underline.member("rects").elements().map(rectangle)

                return DrawnUnderline(
                    rects: rects,
                    color: try color(underline.member("color")),
                    bands: try bands(underline.member("bands"), count: rects.count)
                )
            },
            glyphs: try glyphs(run.member("glyphs"))
        )
    }

    // A band is `[x0, x1]`, x0 no greater than x1, one for each of the `count` rectangles.
    private func bands(
        _ value: PlacedJSONValue,
        count: Int
    ) throws -> [ClosedRange<Double>]? {
        try value.optional { value in
            let elements = try value.elements()
            guard elements.count == count else { throw value.wrongType("a band for each rect, \(count) in all") }

            return try elements.map { element in
                let numbers = try element.numbers(count: 2)
                guard numbers[0] <= numbers[1] else { throw element.wrongType("[x0, x1] with x0 no greater than x1") }

                return numbers[0]...numbers[1]
            }
        }
    }

    private func units(of animation: PlacedJSONObject) throws -> UnitStagger? {
        let by = try animation.member("by")
        let stagger = try animation.member("stagger")
        let order = try animation.member("order")
        guard !by.isNull else {
            guard stagger.isNull else { throw stagger.wrongType("null where `by` is null") }
            guard order.isNull else { throw order.wrongType("null where `by` is null") }

            return nil
        }

        let unit = try by.name(among: TextUnit.allCases.map(\.rawValue), TextUnit.init(rawValue:))
        let seconds = try stagger.number()
        guard seconds >= 0 else { throw stagger.wrongType("a number 0 or more") }
        let ranking = try order.name(among: UnitOrder.allCases.map(\.rawValue), UnitOrder.init(rawValue:))

        return UnitStagger(by: unit, stagger: seconds, order: ranking)
    }

    // A unit's part is `[run, piece, x0, x1]`: a piece of one of `runs` with a highlight or an underline, the piece one
    // of that run's highlight pieces and of its underline pieces where it has each, and its span from x0 to x1.
    private func unitPart(
        _ value: PlacedJSONValue,
        in runs: [ResolvedGlyphRun]
    ) throws -> UnitPart {
        let numbers = try value.numbers(count: 4)
        guard
            let run = Int(exactly: numbers[0]),
            let piece = Int(exactly: numbers[1]),
            runs.indices.contains(run),
            runs[run].highlight != nil || runs[run].underline != nil,
            runs[run].highlight.map({ $0.rects.indices.contains(piece) }) ?? true,
            runs[run].underline.map({ $0.rects.indices.contains(piece) }) ?? true,
            numbers[2] <= numbers[3]
        else {
            throw value.wrongType("[run, piece, x0, x1] naming a highlight or underline piece of one of the title's runs")
        }

        return UnitPart(run: run, piece: piece, span: numbers[2]...numbers[3])
    }

    // A line's cluster is `[run, first, count, start, end, advance, level, cursive]`, its glyphs a range that starts at
    // a glyph of one of the glyph runs `glyphCounts` counts, or at a run's end for a range of count 0, and lies in that
    // run and the runs after it, its scalars a range of at least one of the text's `scalarCount`, its level an embedding
    // level UAX #9 can give and `cursive` the cursive scripts it is a letter of, ISO 15924 codes separated by single
    // spaces, none twice, or empty for none.
    private func cluster(
        _ value: PlacedJSONValue,
        glyphCounts: [Int],
        scalarCount: Int
    ) throws -> PlacedCluster {
        let form = "[run, first, count, start, end, advance, level, cursive]"
        let elements = try value.elements()
        guard elements.count == 8 else { throw value.wrongType("\(form) within the text's \(scalarCount) scalars") }
        let numbers = try elements.prefix(7).map { try $0.number() }
        let written = try elements[7].string()
        let cursiveScripts = written.isEmpty
            ? []
            : written.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard
            cursiveScripts.allSatisfy(isScriptCode),
            Set(cursiveScripts).count == cursiveScripts.count
        else {
            throw elements[7].wrongType("distinct ISO 15924 script codes separated by spaces")
        }
        guard
            let run = Int(exactly: numbers[0]),
            let first = Int(exactly: numbers[1]),
            let count = Int(exactly: numbers[2]),
            let start = Int(exactly: numbers[3]),
            let end = Int(exactly: numbers[4]),
            let level = Int(exactly: numbers[6]),
            glyphCounts.indices.contains(run),
            first >= 0,
            count >= 0,
            first <= glyphCounts[run],
            start >= 0,
            start < end,
            end <= scalarCount,
            level >= 0,
            level <= BidiResolver.maxLevel
        else {
            throw value.wrongType("\(form) within the text's \(scalarCount) scalars")
        }

        let glyphs = GlyphRange(run: run, first: first, count: count)
        guard glyphs.ranges(within: glyphCounts).map(\.count).reduce(0, +) == count else {
            throw value.wrongType("\(form) whose glyphs lie in its run and the runs after it")
        }

        return PlacedCluster(
            glyphs: glyphs,
            range: start..<end,
            advance: numbers[5],
            level: level,
            cursiveScripts: cursiveScripts
        )
    }

    // An ISO 15924 code is four ASCII letters, the first upper case and the rest lower case.
    private func isScriptCode(_ code: String) -> Bool {
        let scalars = Array(code.unicodeScalars)

        return scalars.count == 4
            && ("A"..."Z").contains(scalars[0])
            && scalars.dropFirst().allSatisfy { ("a"..."z").contains($0) }
    }

    // A line's clusters and its hanging spaces, taken in the order they are placed in with those with no glyph of their
    // own left out, each start at the pen start of the one before plus its advance, plus the static tracking of the run
    // of the character `PlacedLine.placedOwners` puts between them, when it puts one. The rightmost character ends at the
    // leftmost one's pen start plus the line's width, and a line with no character taken has a width of 0. A pen start
    // is read along the line's axis, as `writingMode` turns it.
    private func pensFollow(
        on line: PlacedLine,
        runs: [ResolvedGlyphRun],
        writingMode: WritingMode
    ) -> Bool {
        let tolerance = 1e-6
        let placed = line.clusters + line.hanging
        let owners = line.placedOwners
        let pen = { (index: Int) in
            let glyph = runs[placed[index].glyphs.run].glyphs[placed[index].glyphs.first]

            return writingMode.turned(Point(x: glyph.x, y: glyph.y)).x
        }

        for (previous, owner) in zip(owners.map(\.index), owners.dropFirst()) {
            let tracking = owner.tracking.map { runs[placed[$0].glyphs.run].staticTracking } ?? 0
            guard abs(pen(previous) + placed[previous].advance + tracking - pen(owner.index)) <= tolerance else { return false }
        }

        let characters = owners.map(\.index).filter { $0 < line.clusters.count }
        guard let first = characters.first, let last = characters.last else { return abs(line.width) <= tolerance }

        return abs(pen(first) + line.width - pen(last) - placed[last].advance) <= tolerance
    }

    // A range is `[start, end]`, counted in Unicode scalars, within the text's `scalarCount`.
    private func scalarRange(
        _ value: PlacedJSONValue,
        in scalarCount: Int
    ) throws -> Range<Int> {
        let numbers = try value.numbers(count: 2)
        guard
            let start = Int(exactly: numbers[0]),
            let end = Int(exactly: numbers[1]),
            start >= 0,
            start <= end,
            end <= scalarCount
        else {
            throw value.wrongType("[start, end] within the text's \(scalarCount) scalars")
        }

        return start..<end
    }

    // A unit's characters are `[line, first, count]`, a stretch of the clusters of one of `lines`.
    private func characters(
        _ value: PlacedJSONValue,
        in lines: [PlacedLine]
    ) throws -> CharacterRange {
        let numbers = try value.numbers(count: 3)
        guard
            let line = Int(exactly: numbers[0]),
            let first = Int(exactly: numbers[1]),
            let count = Int(exactly: numbers[2]),
            lines.indices.contains(line),
            first >= 0,
            count >= 0,
            first + count <= lines[line].clusters.count
        else {
            throw value.wrongType("[line, first, count]")
        }

        return CharacterRange(line: line, first: first, count: count)
    }

    // A drawn glyph is `[id, x, y]`, where it is drawn, read with no placement offset, its id one an OpenType face can
    // hold.
    private func glyphs(_ value: PlacedJSONValue) throws -> [PositionedGlyph] {
        try value.elements().map { element in
            let numbers = try element.numbers(count: 3)
            guard let id = UInt16(exactly: numbers[0]) else {
                throw element.wrongType("[glyph id, x, y] with a glyph id from 0 to 65535")
            }

            return PositionedGlyph(id: Int(id), x: numbers[1], y: numbers[2])
        }
    }

    // `op` names the operation, and the rest of its keys are its values.
    private func operation(
        _ value: PlacedJSONValue,
        grainKeys: [String]
    ) throws -> ResolvedFilterOperation {
        let names = FilterKeyTable.operations
        let name = try value.object(keys: ["op", "ev", "amount", "kelvin", "degrees", "input", "output", "file", "sha256",
                                            "space", "radius", "color", "offset", "size"] + grainKeys)
            .member("op")
            .name(among: names) { names.contains($0) ? $0 : nil }
        let keys = { (keys: [String]) in try value.object(keys: ["op"] + keys) }
        let number = { (object: PlacedJSONObject, key: String) in try object.member(key).number() }

        switch name {
        case "exposure":
            let operation = try keys(["ev"])
            return .exposure(ev: try number(operation, "ev"))

        case "contrast":
            let operation = try keys(["amount"])
            return .contrast(amount: try number(operation, "amount"))

        case "saturation":
            let operation = try keys(["amount"])
            return .saturation(amount: try number(operation, "amount"))

        case "temperature":
            let operation = try keys(["kelvin"])
            return .temperature(kelvin: try number(operation, "kelvin"))

        case "hue":
            let operation = try keys(["degrees"])
            return .hue(degrees: try number(operation, "degrees"))

        case "sepia":
            let operation = try keys(["amount"])
            return .sepia(amount: try number(operation, "amount"))

        case "levels":
            let operation = try keys(["input", "output"])
            return .levels(
                input: try operation.member("input").numbers(),
                output: try operation.member("output").numbers()
            )

        case "lut":
            let operation = try keys(["file", "sha256", "amount", "space"])
            return .lut(
                file: try pinned(operation),
                amount: try number(operation, "amount"),
                space: try operation.member("space")
                    .name(among: VocabularyTable.lookUpTableSpaces, LookUpTableSpace.init)
            )

        case "blur":
            let operation = try keys(["radius"])
            return .blur(radius: try number(operation, "radius"))

        case "sharpen":
            let operation = try keys(["amount", "radius"])
            return .sharpen(amount: try number(operation, "amount"), radius: try number(operation, "radius"))

        case "bloom":
            let operation = try keys(["amount", "radius", "color"])
            return .bloom(
                amount: try number(operation, "amount"),
                radius: try number(operation, "radius"),
                color: try operation.member("color").optional(color)
            )

        case "vignette":
            let operation = try keys(["amount", "radius"])
            return .vignette(amount: try number(operation, "amount"), radius: try number(operation, "radius"))

        case "displace":
            let operation = try keys(["file", "sha256", "amount", "offset"])
            return .displace(
                file: try pinned(operation),
                amount: try number(operation, "amount"),
                offset: try point(operation.member("offset"))
            )

        case "pixelate":
            let operation = try keys(["size"])
            return .pixelate(size: try number(operation, "size"))

        default:
            let operation = try keys(["amount", "size"] + grainKeys)
            return .grain(amount: try number(operation, "amount"), size: try number(operation, "size"))
        }
    }
    // A page's number, a whole number from 1.
    private func pageNumber(_ value: PlacedJSONValue) throws -> Int {
        let page = try value.integer()
        guard page >= 1 else {
            throw ModelError.wrongType(
                place: value.place,
                kind: value.kind,
                expected: "a whole number, 1 or more",
                found: value.finding
            )
        }

        return page
    }
}
