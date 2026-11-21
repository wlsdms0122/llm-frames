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
    package var machineOutput: JSONValue {
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
                JSONMember(key: "preset", value: text(transition.preset)),
                JSONMember(key: "seconds", value: .time(transition.seconds))
            ]))
        }
        let members = [
            JSONMember(key: "place", value: .string(entry.place)),
            JSONMember(key: "id", value: text(entry.id)),
            JSONMember(key: "media", value: media(of: entry)),
            JSONMember(key: "edit", value: output(entry.edit)),
            JSONMember(key: "drawn", value: output(entry.drawn)),
            JSONMember(key: "clip", value: output(entry.clip)),
            JSONMember(key: "sound", value: entry.sound.map(output) ?? .null),
            JSONMember(key: "speed", value: .number(entry.speed)),
            JSONMember(key: "timeRemap", value: .bool(entry.isTimeRemapped)),
            JSONMember(key: "transition", value: transition ?? .null)
        ]

        return .object(JSONObject(members: members + nested(entry.nested)))
    }

    private func output(_ entry: TimelineClipEntry) -> JSONValue {
        let animation = entry.animation.map { animation in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "entrance", value: output(animation.entrance, length: "seconds")),
                JSONMember(key: "loop", value: output(animation.loop, length: "period")),
                JSONMember(key: "exit", value: output(animation.exit, length: "seconds")),
                JSONMember(key: "by", value: animation.units.map { .string($0.by.rawValue) } ?? .null),
                JSONMember(key: "stagger", value: animation.units.map { .number($0.stagger) } ?? .null)
            ]))
        }
        let members = [
            JSONMember(key: "place", value: .string(entry.place)),
            JSONMember(key: "id", value: text(entry.id)),
            JSONMember(key: "kind", value: .string(entry.kind)),
            JSONMember(key: "visible", value: output(entry.visible)),
            JSONMember(key: "sound", value: entry.sound.map(output) ?? .null),
            JSONMember(key: "lane", value: entry.lane.map { .number(Double($0)) } ?? .null),
            JSONMember(key: "storyline", value: text(entry.storyline)),
            JSONMember(key: "parent", value: text(entry.parent)),
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
            JSONMember(key: "preset", value: text(span.preset)),
            JSONMember(key: key, value: .time(span.length))
        ]))
    }

    private func output(_ range: TimeRange) -> JSONValue {
        .array([.time(range.start), .time(range.end)])
    }

    // The file as written, and for a page of a PDF the `{file, page}` object.
    private func media(of entry: TimelineStorylineEntry) -> JSONValue {
        guard let file = entry.media, let page = entry.page else { return text(entry.media) }

        return .object(JSONObject(members: [
            JSONMember(key: "file", value: .string(file)),
            JSONMember(key: "page", value: .number(Double(page)))
        ]))
    }

    private func text(_ string: String?) -> JSONValue {
        string.map(JSONValue.string) ?? .null
    }

    private func nested(_ report: TimelineReport?) -> [JSONMember] {
        report.map { [JSONMember(key: "nested", value: $0.machineOutput)] } ?? []
    }
}
