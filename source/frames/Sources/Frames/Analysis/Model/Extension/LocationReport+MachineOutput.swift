//
//  LocationReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"locate": "0.1.0", hits}`, the object `locate` prints, each hit `{place, id, kind, item}` and for a picture of media
// also the frame it draws, `media`, `mediaTime` and `page`, as `evaluate` gives them, with `point`, `[x, y]` in that
// frame's pixels or `null`.
extension LocationReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "locate", value: .string(FramesVersion.current)),
            JSONMember(key: "hits", value: .array(hits.map(output)))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func output(_ hit: LocationHit) -> JSONValue {
        let media = hit.media.map { media in
            media.frame.machineOutput(point: JSONMember(
                key: "point",
                value: media.point.map { .array([.measure($0.x), .measure($0.y)]) } ?? .null
            ))
        }

        let item = JSONMember(key: "item", value: .string(hit.item.rawValue))

        return .object(JSONObject(members: hit.origin.machineOutput + [item] + (media ?? [])))
    }
}
