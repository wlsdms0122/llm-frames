//
//  EvaluationReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"evaluate": "1.0.0", time, size, items}`, the object `evaluate` prints, each item `{place, id, kind, item,
// bounds, opacity, transform, rect}` with `bounds` as `[x, y, w, h]` in output pixels, or `null` where it covers
// nothing, `transform` as `[a, b, c, d, tx, ty]` and `rect` as `[x, y, w, h]` in the item's own coordinates.
extension EvaluationReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "evaluate", value: .string(FramesVersion.current)),
            JSONMember(key: "time", value: .time(time)),
            JSONMember(key: "size", value: .array([.measure(size.width), .measure(size.height)])),
            JSONMember(key: "items", value: .array(items.map(output)))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func output(_ item: EvaluationItem) -> JSONValue {
        let transform = item.transform

        return .object(JSONObject(members: item.origin.machineOutput + [
            JSONMember(key: "item", value: .string(item.item.rawValue)),
            JSONMember(key: "bounds", value: item.bounds.map(output) ?? .null),
            JSONMember(key: "opacity", value: .measure(item.opacity)),
            JSONMember(key: "transform", value: .array(
                [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].map(JSONValue.measure)
            )),
            JSONMember(key: "rect", value: output(item.rect))
        ]))
    }

    private func output(_ rectangle: Rectangle) -> JSONValue {
        .array([.measure(rectangle.x), .measure(rectangle.y), .measure(rectangle.width), .measure(rectangle.height)])
    }
}
