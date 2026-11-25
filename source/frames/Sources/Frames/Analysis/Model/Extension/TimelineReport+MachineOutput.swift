//
//  TimelineReport+MachineOutput.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `{"timeline": "0.1.0", duration, storyline, clips}`, the object `timeline --json` prints, with `time` after
// `duration` when it is asked at a time, where a storyline entry also has `clipTime` and every entry `mediaTime`.
// Every entry has `kind`, `media`, its pinned path or `null`, and `page`, and after its own keys `fps`, `instant`,
// `clock`, `space`, `ownSpace` and `tracked`. A nested document's object has the same form.
extension TimelineReport {
    // MARK: - Property
    package var machineOutput: JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "timeline", value: .string(FramesVersion.current)),
            JSONMember(key: "duration", value: .time(duration))
        ] + (time.map { [JSONMember(key: "time", value: .time($0))] } ?? []) + [
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
            JSONMember(key: "kind", value: .string(entry.kind)),
            JSONMember(key: "media", value: text(entry.media)),
            JSONMember(key: "page", value: page(entry.page)),
            JSONMember(key: "edit", value: output(entry.edit)),
            JSONMember(key: "drawn", value: output(entry.drawn)),
            JSONMember(key: "clip", value: output(entry.clip)),
            JSONMember(key: "sound", value: entry.sound.map(output) ?? .null),
            JSONMember(key: "speed", value: .number(entry.speed)),
            JSONMember(key: "timeRemap", value: .bool(entry.isTimeRemapped)),
            JSONMember(key: "transition", value: transition ?? .null)
        ] + written(entry.fps, entry.instant, entry.clock, entry.space, entry.ownSpace, entry.tracked)
        let time = entry.time.map { time in
            [
                JSONMember(key: "clipTime", value: .time(time.clipTime)),
                JSONMember(key: "mediaTime", value: mediaTime(time.mediaTime))
            ]
        }

        return .object(JSONObject(members: members + (time ?? []) + nested(entry.nested)))
    }

    private func output(_ entry: TimelineClipEntry) -> JSONValue {
        let animation = entry.animation.map { animation in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "entrance", value: output(animation.entrance, length: "seconds")),
                JSONMember(key: "loop", value: output(animation.loop, length: "period")),
                JSONMember(key: "exit", value: output(animation.exit, length: "seconds")),
                JSONMember(key: "by", value: animation.units.map { .string($0.by.rawValue) } ?? .null),
                JSONMember(key: "stagger", value: animation.units.map { .number($0.stagger) } ?? .null),
                JSONMember(key: "order", value: animation.units.map { .string($0.order.rawValue) } ?? .null)
            ]))
        }
        let members = [
            JSONMember(key: "place", value: .string(entry.place)),
            JSONMember(key: "id", value: text(entry.id)),
            JSONMember(key: "kind", value: .string(entry.kind)),
            JSONMember(key: "media", value: text(entry.media)),
            JSONMember(key: "page", value: page(entry.page)),
            JSONMember(key: "visible", value: output(entry.visible)),
            JSONMember(key: "sound", value: entry.sound.map(output) ?? .null),
            JSONMember(key: "lane", value: entry.lane.map { .number(Double($0)) } ?? .null),
            JSONMember(key: "storyline", value: text(entry.storyline)),
            JSONMember(key: "parent", value: text(entry.parent)),
            JSONMember(key: "animation", value: animation ?? .null)
        ] + written(entry.fps, entry.instant, entry.clock, entry.space, entry.ownSpace, entry.tracked)
        let time = entry.time.map { [JSONMember(key: "mediaTime", value: mediaTime($0.mediaTime))] }

        return .object(JSONObject(members: members + (time ?? []) + nested(entry.nested)))
    }

    // An entry's image sequence rate, instant, clock, spaces and tracked media, `null` where it has none.
    private func written(
        _ fps: Double?,
        _ instant: Double?,
        _ clock: TimelineClock,
        _ space: CoordinateSpace?,
        _ ownSpace: CoordinateSpace?,
        _ tracked: TimelineTrack?
    ) -> [JSONMember] {
        [
            JSONMember(key: "fps", value: fps.map(JSONValue.number) ?? .null),
            JSONMember(key: "instant", value: instant.map(JSONValue.time) ?? .null),
            JSONMember(key: "clock", value: .object(JSONObject(members: [
                JSONMember(key: "clip", value: text(clock.clip)),
                JSONMember(key: "origin", value: .time(clock.origin)),
                JSONMember(key: "speed", value: .number(clock.speed))
            ]))),
            JSONMember(key: "space", value: space.map(output) ?? .null),
            JSONMember(key: "ownSpace", value: ownSpace.map(output) ?? .null),
            JSONMember(key: "tracked", value: tracked.map(output) ?? .null)
        ]
    }

    private func output(_ tracked: TimelineTrack) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "clip", value: .string(tracked.clip)),
            JSONMember(key: "first", value: .time(tracked.first)),
            JSONMember(key: "last", value: .time(tracked.last))
        ]))
    }

    private func output(_ space: CoordinateSpace) -> JSONValue {
        let (kind, clip): (String, String?) = switch space {
        case .output:
            ("output", nil)

        case let .media(place):
            ("media", place)

        case let .box(place):
            ("box", place)

        case let .text(place):
            ("text", place)
        }

        return .object(JSONObject(members: [
            JSONMember(key: "kind", value: .string(kind)),
            JSONMember(key: "clip", value: text(clip))
        ]))
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

    private func page(_ page: Int?) -> JSONValue {
        page.map { .number(Double($0)) } ?? .null
    }

    private func mediaTime(_ time: Double?) -> JSONValue {
        time.map(JSONValue.time) ?? .null
    }

    private func text(_ string: String?) -> JSONValue {
        string.map(JSONValue.string) ?? .null
    }

    private func nested(_ report: TimelineReport?) -> [JSONMember] {
        report.map { [JSONMember(key: "nested", value: $0.machineOutput)] } ?? []
    }
}
