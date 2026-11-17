//
//  EvaluationReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"evaluate": "1.0.0", time, size, items}`, the object `evaluate` prints, each item `{place, id, kind, bounds,
// opacity}` with `bounds` as `[x, y, w, h]` in output pixels, or `null` where it covers nothing.
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
        let bounds = item.bounds.map { bounds in
            JSONValue.array([.measure(bounds.x), .measure(bounds.y), .measure(bounds.width), .measure(bounds.height)])
        }

        return .object(JSONObject(members: item.origin.machineOutput + [
            JSONMember(key: "bounds", value: bounds ?? .null),
            JSONMember(key: "opacity", value: .measure(item.opacity))
        ]))
    }
}
