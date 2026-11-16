//
//  ResolvedValueWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// Writes the values a resolved sequence and a resolved picture share: geometry, colours, eases, keyframe lists, filter
// operations, shaped text, and files pinned by their absolute path and SHA-256.
struct ResolvedValueWriter: Sendable {
    // MARK: - Property
    private let hashes: any FileHashProvider

    // MARK: - Initializer
    init(hashes: any FileHashProvider) {
        self.hashes = hashes
    }

    // MARK: - Public
    // A path is made absolute against the working directory, the one a relative path was found in.
    func pinned(_ path: String) throws -> [JSONMember] {
        let absolute = URL(fileURLWithPath: path).standardizedFileURL.path

        return [
            JSONMember(key: "file", value: .string(absolute)),
            JSONMember(key: "sha256", value: .string(try hashes.sha256(ofFile: absolute)))
        ]
    }

    // A video or image file with its frame times, nil for a still or sound. An image sequence is its frame files in
    // order, each pinned, so a frame added, removed or changed is refused.
    func media(_ file: MediaFile) throws -> [JSONMember] {
        let pinned = file.frameFiles.isEmpty
            ? try self.pinned(file.path)
            : [JSONMember(key: "imageSequence", value: .array(try file.frameFiles.map { frame in
                .object(JSONObject(members: try self.pinned(frame)))
            }))]
        let frames = file.frameTimes.isEmpty ? [] : [JSONMember(key: "frames", value: numbers(file.frameTimes))]

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
        }
    }

    // A keyframable property as a list of keyframes in sequence time, in time order, each with the ease of the span
    // that starts at it. A static value is one keyframe at `instant`, which holds at every time.
    func keyframes<Value>(
        _ property: PropertyValue<Value>,
        instant: Double,
        value: (Value) throws -> JSONValue
    ) rethrows -> JSONValue {
        let keyframes = switch property {
        case let .value(written):
            [TimedValue(index: 0, at: instant, value: written, ease: .linear)]

        case let .keyframes(keyframes):
            keyframes.enumerated()
                .sorted { left, right in
                    left.element.at == right.element.at ? left.offset < right.offset : left.element.at < right.element.at
                }
                .map(\.element)
        }

        return .array(try keyframes.map { keyframe in
            .object(JSONObject(members: [
                JSONMember(key: "at", value: .number(keyframe.at)),
                JSONMember(key: "value", value: try value(keyframe.value)),
                JSONMember(key: "ease", value: ease(keyframe.ease))
            ]))
        })
    }

    // Each operation is `op` followed by its values, and a LUT's file is pinned.
    func filter(_ operations: [FilterOperation]) throws -> JSONValue {
        .array(try operations.map { operation in
            .object(JSONObject(members: try members(of: operation)))
        })
    }

    // Glyph runs carry their font file pinned, the face in it, size and colour, and each glyph as `[id, x, y]`, its
    // baseline origin in the text's box.
    func text(_ layout: TextLayout) throws -> JSONValue {
        let background = layout.background.map { background in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "color", value: color(background.color)),
                JSONMember(key: "padding", value: size(background.padding)),
                JSONMember(key: "radius", value: .number(background.radius))
            ]))
        }
        let stroke = layout.stroke.map { stroke in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "width", value: .number(stroke.width)),
                JSONMember(key: "color", value: color(stroke.color))
            ]))
        }
        let runs = try layout.runs.map { run in
            JSONValue.object(JSONObject(members: try pinned(run.face.file) + [
                JSONMember(key: "face", value: .string(run.face.name)),
                JSONMember(key: "size", value: .number(run.size)),
                JSONMember(key: "color", value: color(run.color)),
                JSONMember(key: "glyphs", value: .array(run.glyphs.map { numbers([Double($0.id), $0.x, $0.y]) }))
            ]))
        }

        return .object(JSONObject(members: [
            JSONMember(key: "size", value: size(layout.size)),
            JSONMember(key: "lines", value: .number(Double(layout.lineCount))),
            JSONMember(key: "background", value: background ?? .null),
            JSONMember(key: "stroke", value: stroke ?? .null),
            JSONMember(key: "runs", value: .array(runs))
        ]))
    }

    // MARK: - Private
    private func members(of operation: FilterOperation) throws -> [JSONMember] {
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
            return [kind("lut")] + (try pinned(file)) + [value("amount", amount)]

        case let .blur(radius):
            return [kind("blur"), value("radius", radius)]

        case let .sharpen(amount, radius):
            return [kind("sharpen"), value("amount", amount), value("radius", radius)]

        case let .bloom(amount, radius, color):
            return [
                kind("bloom"),
                value("amount", amount),
                value("radius", radius),
                JSONMember(key: "color", value: color.map(JSONValue.string) ?? .null)
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
