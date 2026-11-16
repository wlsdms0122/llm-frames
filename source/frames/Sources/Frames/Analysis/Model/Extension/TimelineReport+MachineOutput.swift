//
//  TimelineReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `{"timeline": "1.0.0", duration, storyline, clips}`, the object `timeline --json` prints. A nested document's
// object has the same form.
extension TimelineReport {
    // MARK: - Property
    var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "timeline", value: .string(FramesVersion.current)),
            JSONMember(key: "duration", value: .time(duration)),
            JSONMember(key: "storyline", value: .array(storyline.map(output))),
            JSONMember(key: "clips", value: .array(clips.map(output)))
        ]))
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func output(_ entry: TimelineStorylineEntry) -> JSONValue {
        let transition = entry.transition.map { transition in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "preset", value: .string(transition.preset)),
                JSONMember(key: "seconds", value: .time(transition.seconds))
            ]))
        }
        let members = [
            JSONMember(key: "place", value: .string(entry.place.description)),
            JSONMember(key: "id", value: text(entry.id)),
            JSONMember(key: "media", value: text(entry.media)),
            JSONMember(key: "edit", value: output(entry.edit)),
            JSONMember(key: "drawn", value: output(entry.drawn)),
            JSONMember(key: "clip", value: output(entry.clip)),
            JSONMember(key: "speed", value: .number(entry.speed)),
            JSONMember(key: "transition", value: transition ?? .null)
        ]

        return .object(JSONObject(members: members + nested(entry.nested)))
    }

    private func output(_ entry: TimelineClipEntry) -> JSONValue {
        let animation = entry.animation.map { animation in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "entrance", value: output(animation.entrance, length: "seconds")),
                JSONMember(key: "loop", value: output(animation.loop, length: "period")),
                JSONMember(key: "exit", value: output(animation.exit, length: "seconds"))
            ]))
        }
        let members = [
            JSONMember(key: "place", value: .string(entry.place.description)),
            JSONMember(key: "id", value: text(entry.id)),
            JSONMember(key: "kind", value: .string(entry.kind)),
            JSONMember(key: "visible", value: output(entry.visible)),
            JSONMember(key: "lane", value: entry.lane.map { .number(Double($0)) } ?? .null),
            JSONMember(key: "parent", value: text(entry.parent?.description)),
            JSONMember(key: "animation", value: animation ?? .null)
        ]

        return .object(JSONObject(members: members + nested(entry.nested)))
    }

    // A span writes its length under the key its preset uses for it.
    private func output(
        _ span: TimelineSpan?,
        length key: String
    ) -> JSONValue {
        guard let span else { return .null }

        return .object(JSONObject(members: [
            JSONMember(key: "preset", value: .string(span.preset)),
            JSONMember(key: key, value: .time(span.length))
        ]))
    }

    private func output(_ range: TimeRange) -> JSONValue {
        .array([.time(range.start), .time(range.end)])
    }

    private func text(_ string: String?) -> JSONValue {
        string.map(JSONValue.string) ?? .null
    }

    private func nested(_ report: TimelineReport?) -> [JSONMember] {
        report.map { [JSONMember(key: "nested", value: $0.machineOutput)] } ?? []
    }
}
