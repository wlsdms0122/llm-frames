//
//  EvaluationReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"evaluate": "0.1.0", time, size, items, texts}`, the object `evaluate` prints. Each item is `{place, id, kind,
// item, bounds, opacity, transform, rect, cornerPins, characters}` with `bounds` as `[x, y, w, h]` in output pixels, or
// `null` where it covers nothing, `transform` as `[a, b, c, d, tx, ty]`, `rect` as `[x, y, w, h]` in the item's own
// coordinates, `cornerPins` a list of `{dest, cornerPin}`, each four points `[x, y]`, or `null` on an item no corner
// pin carries, and `characters` a list of `{text, range, level, rect, baseline}`, or `null` on an item that reports
// none, and a picture of a media file also has the frame it draws, `media`, `mediaTime` and `page`. Each text is `{place, id, text, writingMode, direction, size, box, transform, cornerPins, lines, words}`,
// `writingMode` `horizontal-tb`, `vertical-rl` or `vertical-lr`, `direction` `ltr` or `rtl`, each line `{text, range, baseline, ascent, descent}` and each word `{text, range}`. A range is
// `[start, end]` in whole Unicode scalars.
extension EvaluationReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "evaluate", value: .string(FramesVersion.current)),
            JSONMember(key: "time", value: .time(time)),
            JSONMember(key: "size", value: output(size)),
            JSONMember(key: "items", value: .array(items.map(output))),
            JSONMember(key: "texts", value: .array(texts.map(output)))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func output(_ item: EvaluationItem) -> JSONValue {
        .object(JSONObject(members: item.origin.machineOutput + [
            JSONMember(key: "item", value: .string(item.item.rawValue)),
            JSONMember(key: "bounds", value: item.bounds.map(output) ?? .null),
            JSONMember(key: "opacity", value: .measure(item.opacity)),
            JSONMember(key: "transform", value: output(item.transform)),
            JSONMember(key: "rect", value: output(item.rect)),
            JSONMember(key: "cornerPins", value: output(item.cornerPins)),
            JSONMember(key: "characters", value: item.characters.map { .array($0.map(output)) } ?? .null)
        ] + (item.frame?.machineOutput() ?? [])))
    }

    private func output(_ character: EvaluationCharacter) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "text", value: .string(character.text)),
            JSONMember(key: "range", value: output(character.range)),
            JSONMember(key: "level", value: .number(Double(character.level))),
            JSONMember(key: "rect", value: output(character.rect)),
            JSONMember(key: "baseline", value: .measure(character.baseline))
        ]))
    }

    private func output(_ text: EvaluationText) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(text.place)),
            JSONMember(key: "id", value: text.id.map(JSONValue.string) ?? .null),
            JSONMember(key: "text", value: .string(text.text)),
            JSONMember(key: "writingMode", value: .string(text.writingMode.rawValue)),
            JSONMember(key: "direction", value: .string(text.direction.rawValue)),
            JSONMember(key: "size", value: output(text.size)),
            JSONMember(key: "box", value: output(text.box)),
            JSONMember(key: "transform", value: output(text.transform)),
            JSONMember(key: "cornerPins", value: output(text.cornerPins)),
            JSONMember(key: "lines", value: .array(text.lines.map(output))),
            JSONMember(key: "words", value: .array(text.words.map(output)))
        ]))
    }

    private func output(_ line: EvaluationLine) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "text", value: .string(line.text)),
            JSONMember(key: "range", value: output(line.range)),
            JSONMember(key: "baseline", value: .measure(line.baseline)),
            JSONMember(key: "ascent", value: .measure(line.ascent)),
            JSONMember(key: "descent", value: .measure(line.descent))
        ]))
    }

    private func output(_ word: EvaluationWord) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "text", value: .string(word.text)),
            JSONMember(key: "range", value: output(word.range))
        ]))
    }

    private func output(_ cornerPins: [EvaluationCornerPin]?) -> JSONValue {
        cornerPins.map { cornerPins in
            .array(cornerPins.map { cornerPin in
                .object(JSONObject(members: [
                    JSONMember(key: "dest", value: output(cornerPin.destination)),
                    JSONMember(key: "cornerPin", value: output(cornerPin.cornerPin))
                ]))
            })
        } ?? .null
    }

    private func output(_ quad: Quad) -> JSONValue {
        .array(quad.corners.map { .array([.measure($0.x), .measure($0.y)]) })
    }

    private func output(_ transform: AffineTransform) -> JSONValue {
        .array([transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].map(JSONValue.measure))
    }

    private func output(_ rectangle: Rectangle) -> JSONValue {
        .array([.measure(rectangle.x), .measure(rectangle.y), .measure(rectangle.width), .measure(rectangle.height)])
    }

    private func output(_ size: Size) -> JSONValue {
        .array([.measure(size.width), .measure(size.height)])
    }

    private func output(_ range: Range<Int>) -> JSONValue {
        .array([.number(Double(range.lowerBound)), .number(Double(range.upperBound))])
    }
}
