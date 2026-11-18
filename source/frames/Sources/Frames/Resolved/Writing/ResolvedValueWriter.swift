//
//  ResolvedValueWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes the values a resolved sequence and a resolved picture share: geometry, colours, eases, keyframe lists, filter
// operations, spans, animations, shaped text, and files pinned by their absolute path and SHA-256.
struct ResolvedValueWriter: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func pinned(_ file: PinnedFile) -> [JSONMember] {
        [
            JSONMember(key: "file", value: .string(file.path)),
            JSONMember(key: "sha256", value: .string(file.sha256))
        ]
    }

    // A video or image file with its frame times, none for a still or sound. An image sequence is its frame files in
    // order, each pinned.
    func media(_ media: PinnedMedia) -> [JSONMember] {
        let pinned = switch media.source {
        case let .file(file):
            self.pinned(file)

        case let .imageSequence(files):
            [JSONMember(key: "imageSequence", value: .array(files.map { .object(JSONObject(members: self.pinned($0))) }))]
        }
        let frames = media.frameTimes.isEmpty ? [] : [JSONMember(key: "frames", value: numbers(media.frameTimes))]

        return pinned + frames
    }

    func numbers(_ numbers: [Double]) -> JSONValue {
        .array(numbers.map(JSONValue.number))
    }

    func rectangle(_ rectangle: Rectangle) -> JSONValue {
        numbers([rectangle.x, rectangle.y, rectangle.width, rectangle.height])
    }

    func point(_ point: Point) -> JSONValue {
        numbers([point.x, point.y])
    }

    func quad(_ quad: Quad) -> JSONValue {
        .array(quad.corners.map(point))
    }

    // A path item's or a mask's geometry, one member named by its form.
    func geometry(_ geometry: PathGeometry) -> JSONValue {
        let form = { (name: String, members: [JSONMember]) in
            JSONValue.object(JSONObject(members: [JSONMember(key: name, value: .object(JSONObject(members: members)))]))
        }

        switch geometry {
        case let .rect(rectangle, radius):
            return form("rect", [
                JSONMember(key: "rect", value: self.rectangle(rectangle)),
                JSONMember(key: "radius", value: .number(radius))
            ])

        case let .ellipse(rectangle):
            return form("ellipse", [JSONMember(key: "rect", value: self.rectangle(rectangle))])

        case let .polyline(points, isClosed):
            return form("polyline", [
                JSONMember(key: "points", value: .array(points.map(self.point))),
                JSONMember(key: "closed", value: .bool(isClosed))
            ])
        }
    }

    // A clip's masks as a keyframe list of mask lists, or `null` for none.
    func masks(_ keyframes: [Keyframe<[ResolvedMask]>]?) -> JSONValue {
        guard let keyframes else { return .null }

        return self.keyframes(keyframes) { masks in
            .array(masks.map { mask in
                .object(JSONObject(members: [
                    JSONMember(key: "geometry", value: geometry(mask.geometry)),
                    JSONMember(key: "feather", value: .number(mask.feather)),
                    JSONMember(key: "invert", value: .bool(mask.isInverted)),
                    JSONMember(key: "mode", value: .string(mask.mode.rawValue))
                ]))
            })
        }
    }

    func size(_ size: Size) -> JSONValue {
        numbers([size.width, size.height])
    }

    func range(_ range: TimeRange?) -> JSONValue {
        range.map { numbers([$0.start, $0.end]) } ?? .null
    }

    func color(_ color: Color) -> JSONValue {
        .string(color.hex)
    }

    func ease(_ ease: Ease) -> JSONValue {
        switch ease {
        case .linear:
            .string("linear")

        case .easeIn:
            .string("ease-in")

        case .easeOut:
            .string("ease-out")

        case .easeInOut:
            .string("ease-in-out")

        case .backOut:
            .string("back-out")

        case .bounceOut:
            .string("bounce-out")

        case .step:
            .string("step")

        case let .cubicBezier(x1, y1, x2, y2):
            numbers([x1, y1, x2, y2])

        case let .spring(bounce):
            .object(JSONObject(members: [
                JSONMember(key: "spring", value: .object(JSONObject(members: [JSONMember(key: "bounce", value: .number(bounce))])))
            ]))
        }
    }

    // A keyframable property as a list of keyframes in sequence time, each with the ease of the span that starts at it.
    func keyframes<Value>(
        _ keyframes: [Keyframe<Value>],
        value: (Value) -> JSONValue
    ) -> JSONValue {
        .array(keyframes.map { keyframe in
            .object(JSONObject(members: [
                JSONMember(key: "at", value: .number(keyframe.at)),
                JSONMember(key: "value", value: value(keyframe.value)),
                JSONMember(key: "ease", value: ease(keyframe.ease))
            ]))
        })
    }

    func numbers(_ keyframes: [Keyframe<Double>]) -> JSONValue {
        self.keyframes(keyframes) { .number($0) }
    }

    // Each operation is `op` followed by its values, and a LUT's file is pinned. A display list's `grain` also carries
    // `seed`, the number of the output frame it is drawn in, which a resolved document has none of.
    func filter(
        _ operations: [ResolvedFilterOperation],
        seed: Int? = nil
    ) -> JSONValue {
        .array(operations.map { operation in
            let members = members(of: operation)
            guard case .grain = operation, let seed else { return .object(JSONObject(members: members)) }

            return .object(JSONObject(members: members + [JSONMember(key: "seed", value: .number(Double(seed)))]))
        })
    }

    // A key's values follow `t` in the order the motion properties are listed, so the same span is written the same way.
    func span(_ span: Span) -> [JSONMember] {
        [
            JSONMember(key: "ease", value: ease(span.ease)),
            JSONMember(key: "revealFrom", value: .string(span.revealFrom.rawValue)),
            JSONMember(key: "keys", value: .array(span.keys.map { key in
                .object(JSONObject(members: [JSONMember(key: "t", value: .number(key.t))] + MotionProperty.allCases.compactMap { property in
                    key.values[property].map { JSONMember(key: property.rawValue, value: .number($0)) }
                }))
            }))
        ]
    }

    // An entrance and an exit by their `seconds`, a loop by its `period`.
    func animation(_ animation: ResolvedAnimation) -> JSONValue {
        let span = { (span: AnimationSpan?, length: String) -> JSONValue in
            span.map { span in
                .object(JSONObject(members: [JSONMember(key: length, value: .number(span.length))] + self.span(span.span)))
            } ?? .null
        }

        return .object(JSONObject(members: [
            JSONMember(key: "entrance", value: span(animation.entrance, "seconds")),
            JSONMember(key: "loop", value: span(animation.loop, "period")),
            JSONMember(key: "exit", value: span(animation.exit, "seconds"))
        ]))
    }

    // Glyph runs carry their font file pinned, the face in it, size, colour and stroke, and each glyph as `[id, x, y]`,
    // its baseline origin in the text's box.
    func text(_ text: ResolvedText) -> JSONValue {
        let background = text.background.map { background in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "color", value: color(background.color)),
                JSONMember(key: "padding", value: size(background.padding)),
                JSONMember(key: "radius", value: .number(background.radius))
            ]))
        }

        return .object(JSONObject(members: [
            JSONMember(key: "size", value: size(text.size)),
            JSONMember(key: "background", value: background ?? .null),
            JSONMember(key: "runs", value: runs(text.runs))
        ]))
    }

    func runs(_ runs: [ResolvedGlyphRun]) -> JSONValue {
        .array(runs.map { run in
            .object(JSONObject(members: pinned(run.font) + [
                JSONMember(key: "face", value: .string(run.face)),
                JSONMember(key: "size", value: .number(run.size)),
                JSONMember(key: "color", value: color(run.color)),
                JSONMember(key: "stroke", value: run.stroke.map(stroke) ?? .null),
                JSONMember(key: "glyphs", value: .array(run.glyphs.map { numbers([Double($0.id), $0.x, $0.y]) }))
            ]))
        })
    }

    // MARK: - Private
    private func stroke(_ stroke: TextStroke) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "width", value: .number(stroke.width)),
            JSONMember(key: "color", value: color(stroke.color))
        ]))
    }

    private func members(of operation: ResolvedFilterOperation) -> [JSONMember] {
        let kind = { (name: String) in JSONMember(key: "op", value: .string(name)) }
        let value = { (key: String, number: Double) in JSONMember(key: key, value: .number(number)) }

        switch operation {
        case let .exposure(ev):
            return [kind("exposure"), value("ev", ev)]

        case let .contrast(amount):
            return [kind("contrast"), value("amount", amount)]

        case let .saturation(amount):
            return [kind("saturation"), value("amount", amount)]

        case let .temperature(kelvin):
            return [kind("temperature"), value("kelvin", kelvin)]

        case let .hue(degrees):
            return [kind("hue"), value("degrees", degrees)]

        case let .sepia(amount):
            return [kind("sepia"), value("amount", amount)]

        case let .levels(input, output):
            return [
                kind("levels"),
                JSONMember(key: "input", value: numbers(input)),
                JSONMember(key: "output", value: numbers(output))
            ]

        case let .lut(file, amount):
            return [kind("lut")] + pinned(file) + [value("amount", amount)]

        case let .blur(radius):
            return [kind("blur"), value("radius", radius)]

        case let .sharpen(amount, radius):
            return [kind("sharpen"), value("amount", amount), value("radius", radius)]

        case let .bloom(amount, radius, color):
            return [
                kind("bloom"),
                value("amount", amount),
                value("radius", radius),
                JSONMember(key: "color", value: color.map(self.color) ?? .null)
            ]

        case let .vignette(amount, radius):
            return [kind("vignette"), value("amount", amount), value("radius", radius)]

        case let .pixelate(size):
            return [kind("pixelate"), value("size", size)]

        case let .grain(amount, size):
            return [kind("grain"), value("amount", amount), value("size", size)]
        }
    }
}
