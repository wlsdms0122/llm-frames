//
//  ResolvedValueWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes the values a resolved sequence, a display list and a mix plan share: geometry, colours, paints, eases,
// keyframe lists, filter operations, spans, animations, shaped text, and files pinned by their absolute path and
// SHA-256.
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

    // A clip area keeps its form, its padding in output pixels, and a point of one keeps `{area, point}`.
    func geometryArea(_ area: GeometryArea) -> JSONValue {
        switch area {
        case let .rectangle(rectangle):
            self.rectangle(rectangle)

        case let .clip(area):
            clipArea(area)
        }
    }

    func geometryAnchor(_ anchor: GeometryAnchor) -> JSONValue {
        switch anchor {
        case let .point(point):
            self.point(point)

        case let .named(name):
            .string(name)
        }
    }

    func geometryPoint(_ point: GeometryPoint) -> JSONValue {
        switch point {
        case let .point(point):
            self.point(point)

        case let .clip(area, name):
            .object(JSONObject(members: [
                JSONMember(key: "area", value: clipArea(area)),
                JSONMember(key: "point", value: .string(name))
            ]))
        }
    }

    func quad(_ quad: Quad) -> JSONValue {
        .array(quad.corners.map(point))
    }

    // A path item's fill or stroke paint: a colour, or a gradient as one member named by its kind, its stops
    // `[offset, colour]`.
    func paint(_ paint: Paint) -> JSONValue {
        switch paint {
        case let .color(color):
            return self.color(color)

        case let .gradient(gradient):
            let stops = JSONMember(key: "stops", value: .array(gradient.stops.map { stop in
                .array([.number(stop.offset), color(stop.color)])
            }))
            let (name, members) = switch gradient.shape {
            case let .linear(from, to):
                ("linear", [JSONMember(key: "from", value: point(from)), JSONMember(key: "to", value: point(to)), stops])

            case let .radial(center, radius):
                (
                    "radial",
                    [JSONMember(key: "center", value: point(center)), JSONMember(key: "radius", value: .number(radius)), stops]
                )
            }

            return .object(JSONObject(members: [JSONMember(key: name, value: .object(JSONObject(members: members)))]))
        }
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

    // A clip's masks in order, or `null` for none. Each number of a mask's geometry and its feather is a keyframe list:
    // a rect's or an ellipse's `rect`, or its box `width`, `height` and `position`, a rect's `radius`, and each point of
    // a path, a closed polyline.
    func masks(_ masks: [ResolvedMask]?) -> JSONValue {
        guard let masks else { return .null }

        return .array(masks.map { mask in
            .object(JSONObject(members: [
                JSONMember(key: "geometry", value: geometry(mask.geometry)),
                JSONMember(key: "feather", value: numbers(mask.feather)),
                JSONMember(key: "invert", value: .bool(mask.isInverted)),
                JSONMember(key: "mode", value: .string(mask.mode.rawValue))
            ]))
        })
    }

    func size(_ size: Size) -> JSONValue {
        numbers([size.width, size.height])
    }

    func range(_ range: TimeRange?) -> JSONValue {
        range.map { numbers([$0.start, $0.end]) } ?? .null
    }

    func color(_ color: Color) -> JSONValue {
        .string(color.resolvedForm)
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

    // A scale is written as its pair, `[sx, sy]`.
    func scales(_ keyframes: [Keyframe<Scale>]) -> JSONValue {
        self.keyframes(keyframes) { scale in numbers([scale.x, scale.y]) }
    }

    // A timed value: each timed leaf as its keyframe list, each static leaf as its value, `off` as `null`, the colour
    // form as its colour, a choice's form as the choice writes it, its name beside its body (`{"op": "blur", ...}`),
    // and any other form as an object of its one name.
    func timed(_ value: TimedValue) -> JSONValue {
        switch value {
        case .off:
            .null

        case let .fixed(value):
            value

        case let .track(keyframes):
            self.keyframes(keyframes) { leaf in
                switch leaf {
                case let .number(number):
                    .number(number)

                case let .color(color):
                    self.color(color)

                case let .numbers(numbers):
                    self.numbers(numbers)

                case let .area(area):
                    geometryArea(.clip(area))

                case let .point(area, name):
                    geometryPoint(.clip(area, point: name))
                }
            }

        case let .object(members):
            .object(JSONObject(members: members.map { JSONMember(key: $0.key, value: timed($0.value)) }))

        case let .list(elements):
            .array(elements.map(timed))

        case let .form(name, body) where name == ValueStructure.colorForm:
            timed(body)

        case let .form(name, body):
            if let separator = name.firstIndex(of: ":"), case let .object(members) = body {
                .object(JSONObject(members: [
                    JSONMember(key: String(name[..<separator]), value: .string(String(name[name.index(after: separator)...])))
                ] + members.map { JSONMember(key: $0.key, value: timed($0.value)) }))
            } else {
                .object(JSONObject(members: [JSONMember(key: name, value: timed(body))]))
            }
        }
    }

    // A display list's filter: each entry its ops, each `op` followed by its values with a LUT's file pinned and a
    // `grain`'s `seed`, the number of the output frame it is drawn in, then its `mix`.
    func filter(
        _ entries: [FilterEntry],
        seed: Int
    ) -> JSONValue {
        .array(entries.map { entry in
            let operations = JSONValue.array(entry.operations.map { operation in
                let members = members(of: operation)
                guard case .grain = operation else { return .object(JSONObject(members: members)) }

                return .object(JSONObject(members: members + [JSONMember(key: "seed", value: .number(Double(seed)))]))
            })
            return .object(JSONObject(members: [
                JSONMember(key: "ops", value: operations),
                JSONMember(key: "mix", value: .number(entry.mix))
            ]))
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

    // An entrance and an exit by their `seconds`, a loop by its `period`, and `by` and `stagger` `null` unless a title
    // plays by unit.
    func animation(_ animation: ResolvedAnimation) -> JSONValue {
        let span = { (span: AnimationSpan?, length: String) -> JSONValue in
            span.map { span in
                .object(JSONObject(members: [JSONMember(key: length, value: .number(span.length))] + self.span(span.span)))
            } ?? .null
        }

        return .object(JSONObject(members: [
            JSONMember(key: "entrance", value: span(animation.entrance, "seconds")),
            JSONMember(key: "loop", value: span(animation.loop, "period")),
            JSONMember(key: "exit", value: span(animation.exit, "seconds")),
            JSONMember(key: "by", value: animation.units.map { .string($0.by.rawValue) } ?? .null),
            JSONMember(key: "stagger", value: animation.units.map { .number($0.stagger) } ?? .null)
        ]))
    }

    // Glyph runs carry their font file pinned, the face in it, size, their timed attributes and their highlight and
    // underline pieces, and each glyph as `[id, x, y]`, its baseline origin in the text's box. A unit's part is
    // `[run, piece, x0, x1]`.
    func text(_ text: ResolvedText) -> JSONValue {
        let background = text.background.map { background in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "color", value: timed(background.color)),
                JSONMember(key: "padding", value: timed(background.padding)),
                JSONMember(key: "radius", value: timed(background.radius))
            ]))
        }

        let lines = text.lines.map { lines in
            JSONValue.array(lines.map { line in
                .object(JSONObject(members: [
                    JSONMember(key: "width", value: .number(line.width)),
                    JSONMember(key: "baseline", value: .number(line.baseline)),
                    JSONMember(key: "clusters", value: .array(line.clusters.map { cluster in
                        numbers([Double(cluster.run), Double(cluster.first), Double(cluster.count)])
                    }))
                ]))
            })
        }

        let units = text.units.map { units in
            JSONValue.array(units.map { unit in
                .object(JSONObject(members: [
                    JSONMember(key: "box", value: rectangle(unit.box)),
                    JSONMember(key: "glyphBox", value: rectangle(unit.glyphBox)),
                    JSONMember(key: "glyphs", value: .array(unit.glyphs.map { glyphs in
                        numbers([Double(glyphs.run), Double(glyphs.first), Double(glyphs.count)])
                    })),
                    JSONMember(key: "parts", value: .array(unit.parts.map { part in
                        numbers([Double(part.run), Double(part.piece), part.span.lowerBound, part.span.upperBound])
                    }))
                ]))
            })
        }

        return .object(JSONObject(members: [
            JSONMember(key: "size", value: size(text.size)),
            JSONMember(key: "textBox", value: rectangle(text.textBox)),
            JSONMember(key: "width", value: text.width.map(JSONValue.number) ?? .null),
            JSONMember(key: "background", value: background ?? .null),
            JSONMember(key: "align", value: .string(text.align.rawValue)),
            JSONMember(key: "lineHeight", value: timed(text.lineHeight)),
            JSONMember(key: "lines", value: lines ?? .null),
            JSONMember(key: "units", value: units ?? .null),
            JSONMember(key: "runs", value: runs(text.runs))
        ]))
    }

    func runs(_ runs: [ResolvedGlyphRun]) -> JSONValue {
        .array(runs.map { run in
            let highlight = run.highlight.map { highlight in
                JSONValue.object(JSONObject(members: [
                    JSONMember(key: "color", value: timed(highlight.color)),
                    JSONMember(key: "padding", value: timed(highlight.padding)),
                    JSONMember(key: "radius", value: timed(highlight.radius)),
                    JSONMember(key: "rects", value: .array(highlight.rects.map(rectangle)))
                ]))
            }
            let underline = run.underline.map { underline in
                JSONValue.object(JSONObject(members: [
                    JSONMember(key: "color", value: timed(underline.color)),
                    JSONMember(key: "width", value: timed(underline.width)),
                    JSONMember(key: "offset", value: timed(underline.offset)),
                    JSONMember(key: "rects", value: .array(underline.rects.map { numbers([$0.x, $0.y, $0.width]) }))
                ]))
            }

            return .object(JSONObject(members: [JSONMember(key: "source", value: .number(Double(run.source)))]
                + pinned(run.font)
                + [
                    JSONMember(key: "face", value: .string(run.face)),
                    JSONMember(key: "size", value: .number(run.size)),
                    JSONMember(key: "color", value: timed(run.color)),
                    JSONMember(key: "stroke", value: timed(run.stroke)),
                    JSONMember(key: "baselineShift", value: timed(run.baselineShift)),
                    JSONMember(key: "tracking", value: timed(run.tracking)),
                    JSONMember(key: "highlight", value: highlight ?? .null),
                    JSONMember(key: "underline", value: underline ?? .null),
                    JSONMember(key: "glyphs", value: glyphs(run.glyphs))
                ]
            ))
        })
    }

    // A `glyphs` item's runs at one instant, each with its colour and stroke.
    func drawnRuns(_ runs: [DrawnGlyphRun]) -> JSONValue {
        .array(runs.map { run in
            .object(JSONObject(members: pinned(run.font) + [
                JSONMember(key: "face", value: .string(run.face)),
                JSONMember(key: "size", value: .number(run.size)),
                JSONMember(key: "color", value: color(run.color)),
                JSONMember(key: "stroke", value: run.stroke.map(stroke) ?? .null),
                JSONMember(key: "highlight", value: run.highlight.map { highlight in
                    .object(JSONObject(members: [
                        JSONMember(key: "rects", value: .array(highlight.rects.map(rectangle))),
                        JSONMember(key: "radius", value: .number(highlight.radius)),
                        JSONMember(key: "color", value: color(highlight.color)),
                        JSONMember(key: "bands", value: bands(highlight.bands))
                    ]))
                } ?? .null),
                JSONMember(key: "underline", value: run.underline.map { underline in
                    .object(JSONObject(members: [
                        JSONMember(key: "rects", value: .array(underline.rects.map(rectangle))),
                        JSONMember(key: "color", value: color(underline.color)),
                        JSONMember(key: "bands", value: bands(underline.bands))
                    ]))
                } ?? .null),
                JSONMember(key: "glyphs", value: glyphs(run.glyphs))
            ]))
        })
    }

    // MARK: - Private
    private func clipArea(_ area: ClipArea) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "clip", value: .string(area.clip)),
            JSONMember(key: "padding", value: .number(area.padding))
        ]))
    }

    private func geometry(_ geometry: ResolvedMaskGeometry) -> JSONValue {
        let form = { (name: String, members: [JSONMember]) in
            JSONValue.object(JSONObject(members: [JSONMember(key: name, value: .object(JSONObject(members: members)))]))
        }

        switch geometry {
        case let .rect(rectangle, radius):
            return form("rect", members(of: rectangle) + [JSONMember(key: "radius", value: numbers(radius))])

        case let .ellipse(rectangle):
            return form("ellipse", members(of: rectangle))

        case let .polyline(points):
            return form("polyline", [
                JSONMember(key: "points", value: .array(points.map { keyframes($0, value: geometryPoint) })),
                JSONMember(key: "closed", value: .bool(true))
            ])
        }
    }

    private func members(of rectangle: ResolvedMaskRectangle) -> [JSONMember] {
        switch rectangle {
        case let .area(area):
            [JSONMember(key: "rect", value: keyframes(area, value: geometryArea))]

        case let .box(width, height, position):
            [
                JSONMember(key: "width", value: numbers(width)),
                JSONMember(key: "height", value: numbers(height)),
                JSONMember(key: "position", value: keyframes(position, value: geometryPoint))
            ]
        }
    }

    private func bands(_ bands: [ClosedRange<Double>]?) -> JSONValue {
        bands.map { bands in .array(bands.map { numbers([$0.lowerBound, $0.upperBound]) }) } ?? .null
    }

    private func glyphs(_ glyphs: [PositionedGlyph]) -> JSONValue {
        .array(glyphs.map { numbers([Double($0.id), $0.x, $0.y]) })
    }

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
