//
//  LocationReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// `{"locate": "1.0.0", hits}`, the object `locate` prints, each hit `{place, id, kind}` and for a picture of media
// also `media`, the file its frame is read from, `mediaTime` and `point`, `[x, y]` in that media's pixels or `null`.
extension LocationReport {
    // MARK: - Property
    var machineOutput: JSONValue {
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
            [
                JSONMember(key: "media", value: .string(media.file)),
                JSONMember(key: "mediaTime", value: .time(media.mediaTime)),
                JSONMember(
                    key: "point",
                    value: media.point.map { .array([.measure($0.x), .measure($0.y)]) } ?? .null
                )
            ]
        }

        return .object(JSONObject(members: hit.origin.machineOutput + (media ?? [])))
    }
}
