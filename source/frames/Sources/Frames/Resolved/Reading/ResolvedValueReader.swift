//
//  ResolvedValueReader.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads the values a resolved sequence and a resolved picture share, as `ResolvedValueWriter` writes them: geometry,
// colours, eases, keyframe lists, filter operations, spans, animations, shaped text, and pinned files.
struct ResolvedValueReader: Sendable {
    // MARK: - Property
    // The keys of pinned media, which an object holding it carries beside its own.
    static let mediaKeys = ["file", "sha256", "imageSequence", "frames"]
    static let spanKeys = ["ease", "revealFrom", "keys"]

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

    // An image sequence is its frame files in order, and the frame times are written only for a video or image
    // sequence.
    func media(_ object: PlacedJSONObject) throws -> PinnedMedia {
        let source: PinnedSource = if object.contains("imageSequence") {
            .imageSequence(try object.member("imageSequence").elements().map { element in
                try pinned(element.object(keys: ["file", "sha256"]))
            })
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

    func size(_ value: PlacedJSONValue) throws -> Size {
        let numbers = try value.numbers(count: 2)

        return Size(width: numbers[0], height: numbers[1])
    }

    func range(_ value: PlacedJSONValue) throws -> TimeRange {
        let numbers = try value.numbers(count: 2)

        return TimeRange(start: numbers[0], end: numbers[1])
    }

    // `#RRGGBBAA`, the one form a resolved document writes a colour in.
    func color(_ value: PlacedJSONValue) throws -> Color {
        let string = try value.string()
        let digits = string.dropFirst()
        guard string.first == "#", digits.count == 8, digits.allSatisfy(\.isHexDigit) else {
            throw value.wrongType("a colour as #RRGGBBAA")
        }

        return Color(written: string)
    }

    func ease(_ value: PlacedJSONValue) throws -> Ease {
        guard let ease = Ease(value: value.value) else { throw value.wrongType("an ease name or [x1, y1, x2, y2]") }

        return ease
    }

    func keyframes<Value: Interpolable>(
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

    func numbers(_ value: PlacedJSONValue) throws -> [Keyframe<Double>] {
        try keyframes(value) { try $0.number() }
    }

    func crops(_ value: PlacedJSONValue) throws -> [Keyframe<Crop>] {
        try keyframes(value) { Crop(try rectangle($0)) }
    }

    // `grainKeys` are the keys a `grain` may hold besides its values: a display list's `seed`, which its reader reads.
    func filter(
        _ value: PlacedJSONValue,
        grainKeys: [String] = []
    ) throws -> [ResolvedFilterOperation] {
        try value.elements().map { try operation($0, grainKeys: grainKeys) }
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

    // An entrance and an exit by their `seconds`, a loop by its `period`, each `null` when it takes none.
    func animation(_ value: PlacedJSONValue) throws -> ResolvedAnimation {
        let animation = try value.object(keys: ["entrance", "loop", "exit"])
        let span = { (key: String, length: String) throws -> AnimationSpan? in
            try animation.member(key).optional { value in
                let span = try value.object(keys: [length] + Self.spanKeys)

                return AnimationSpan(length: try span.member(length).number(), span: try self.span(span))
            }
        }

        return ResolvedAnimation(
            entrance: try span("entrance", "seconds"),
            loop: try span("loop", "period"),
            exit: try span("exit", "seconds")
        )
    }

    func text(_ value: PlacedJSONValue) throws -> ResolvedText {
        let text = try value.object(keys: ["size", "lines", "background", "stroke", "runs"])

        return ResolvedText(
            size: try size(text.member("size")),
            lineCount: try text.member("lines").integer(),
            background: try text.member("background").optional { value in
                let background = try value.object(keys: ["color", "padding", "radius"])

                return TextBackground(
                    color: try color(background.member("color")),
                    padding: try size(background.member("padding")),
                    radius: try background.member("radius").number()
                )
            },
            stroke: try text.member("stroke").optional { value in
                let stroke = try value.object(keys: ["width", "color"])

                return TextStroke(width: try stroke.member("width").number(), color: try color(stroke.member("color")))
            },
            runs: try runs(text.member("runs"))
        )
    }

    func runs(_ value: PlacedJSONValue) throws -> [ResolvedGlyphRun] {
        try value.elements().map(run)
    }

    // MARK: - Private
    // A glyph is `[id, x, y]`, its baseline origin in the text's box.
    private func run(_ value: PlacedJSONValue) throws -> ResolvedGlyphRun {
        let run = try value.object(keys: ["file", "sha256", "face", "size", "color", "glyphs"])

        return ResolvedGlyphRun(
            font: try pinned(run),
            face: try run.member("face").string(),
            size: try run.member("size").number(),
            color: try color(run.member("color")),
            glyphs: try run.member("glyphs").elements().map { element in
                let numbers = try element.numbers(count: 3)
                guard let id = Int(exactly: numbers[0]) else { throw element.wrongType("[glyph id, x, y]") }

                return PositionedGlyph(id: id, x: numbers[1], y: numbers[2])
            }
        )
    }

    // `op` names the operation, and the rest of its keys are its values.
    private func operation(
        _ value: PlacedJSONValue,
        grainKeys: [String]
    ) throws -> ResolvedFilterOperation {
        let names = [
            "exposure", "contrast", "saturation", "temperature", "hue", "sepia", "levels", "lut", "blur", "sharpen",
            "bloom", "vignette", "pixelate", "grain"
        ]
        let name = try value.object(keys: ["op", "ev", "amount", "kelvin", "degrees", "input", "output", "file", "sha256",
                                            "radius", "color", "size"] + grainKeys)
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
            let operation = try keys(["file", "sha256", "amount"])
            return .lut(file: try pinned(operation), amount: try number(operation, "amount"))

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

        case "pixelate":
            let operation = try keys(["size"])
            return .pixelate(size: try number(operation, "size"))

        default:
            let operation = try keys(["amount", "size"] + grainKeys)
            return .grain(amount: try number(operation, "amount"), size: try number(operation, "size"))
        }
    }
}
