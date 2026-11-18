//
//  ResolvedSequenceWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes a resolved sequence as the members of its resolved document after `kind`: its format, its storyline, its
// other clips in document order, and every source of sound. A nested document is written in place of a file.
struct ResolvedSequenceWriter: Sendable {
    // MARK: - Property
    private let values = ResolvedValueWriter()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func members(of sequence: ResolvedSequence) -> [JSONMember] {
        [
            JSONMember(key: "format", value: format(sequence.format)),
            JSONMember(key: "storyline", value: .array(sequence.storyline.map(storyline))),
            JSONMember(key: "clips", value: .array(sequence.clips.map(clip))),
            JSONMember(key: "audio", value: .array(sequence.audio.map(sound)))
        ]
    }

    // A nested sequence is written as a document of its own, without a version, which only the outermost carries.
    func document(_ sequence: ResolvedSequence) -> JSONValue {
        .object(JSONObject(members: [JSONMember(key: "kind", value: .string("sequence"))] + members(of: sequence)))
    }

    // MARK: - Private
    private func format(_ format: ResolvedFormat) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "size", value: values.size(format.size)),
            JSONMember(key: "fps", value: .number(format.fps)),
            JSONMember(key: "duration", value: .number(format.duration)),
            JSONMember(key: "background", value: values.color(format.background)),
            JSONMember(key: "conform", value: .string(format.conform.rawValue))
        ]))
    }

    private func storyline(_ entry: ResolvedStorylineClip) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(entry.place)),
            JSONMember(key: "id", value: entry.id.map(JSONValue.string) ?? .null),
            JSONMember(key: "media", value: entry.media.map(media) ?? .null),
            JSONMember(key: "solid", value: entry.solid.map(values.color) ?? .null),
            JSONMember(key: "in", value: .number(entry.in)),
            JSONMember(key: "out", value: .number(entry.out)),
            JSONMember(key: "speed", value: .number(entry.speed)),
            JSONMember(key: "start", value: .number(entry.start)),
            JSONMember(key: "end", value: .number(entry.end)),
            JSONMember(key: "size", value: values.size(entry.box.size)),
            JSONMember(key: "position", value: values.keyframes(entry.box.position, value: values.point)),
            JSONMember(key: "anchor", value: values.point(entry.box.anchor)),
            JSONMember(key: "crop", value: crops(entry.crop)),
            JSONMember(key: "mask", value: values.masks(entry.mask)),
            JSONMember(key: "trackMatte", value: entry.trackMatte.map(trackMatte) ?? .null),
            JSONMember(key: "track", value: entry.track.map(track) ?? .null),
            JSONMember(key: "opacity", value: values.numbers(entry.opacity)),
            JSONMember(key: "scale", value: values.numbers(entry.scale)),
            JSONMember(key: "rotation", value: values.numbers(entry.rotation)),
            JSONMember(key: "blend", value: .string(entry.blend)),
            JSONMember(key: "filter", value: values.filter(entry.filter)),
            JSONMember(key: "radius", value: .number(entry.radius)),
            JSONMember(key: "border", value: entry.border.map(border) ?? .null),
            JSONMember(key: "shadow", value: entry.shadow.map(shadow) ?? .null),
            JSONMember(key: "transition", value: entry.transition.map(transition) ?? .null)
        ]))
    }

    // What a clip draws comes after its id, a media clip's timing, filter and appearance with it, and a shape's
    // geometry and appearance. Scale, rotation and a blend mode belong to anything drawn but an adjustment. A shape
    // placed by its geometry writes its position and anchor where a box would, and its area with its own keys.
    private func clip(_ clip: ResolvedClip) -> JSONValue {
        let number = { (keyframes: [Keyframe<Double>]) in values.numbers(keyframes) }
        let transform = [
            clip.scale.map { JSONMember(key: "scale", value: number($0)) },
            clip.rotation.map { JSONMember(key: "rotation", value: number($0)) },
            clip.blend.map { JSONMember(key: "blend", value: .string($0)) }
        ].compactMap { $0 }
        let shape: ResolvedShape? = if case let .shape(shape) = clip.content { shape } else { nil }
        let placement = shape?.geometry.placement
        let position = clip.box?.position ?? placement?.position
        let anchor = clip.box?.anchor ?? placement?.anchor
        let geometry = [
            JSONMember(key: "size", value: clip.box.map { values.size($0.size) } ?? .null),
            JSONMember(key: "position", value: position.map { values.keyframes($0, value: values.point) } ?? .null),
            JSONMember(key: "anchor", value: anchor.map(values.point) ?? .null),
            JSONMember(key: "crop", value: clip.crop.map(crops) ?? .null),
            JSONMember(key: "mask", value: values.masks(clip.mask)),
            JSONMember(key: "trackMatte", value: clip.trackMatte.map(trackMatte) ?? .null),
            JSONMember(key: "track", value: clip.track.map(track) ?? .null)
        ]

        return .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(clip.place)),
            JSONMember(key: "id", value: clip.id.map(JSONValue.string) ?? .null)
        ] + content(clip.content) + [
            JSONMember(key: "start", value: .number(clip.start)),
            JSONMember(key: "end", value: .number(clip.end)),
            JSONMember(key: "lane", value: clip.lane.map { .number(Double($0)) } ?? .null),
            JSONMember(key: "storyline", value: clip.storyline.map { .number(Double($0)) } ?? .null),
            JSONMember(key: "parent", value: clip.parent.map(JSONValue.string) ?? .null)
        ] + geometry + [
            JSONMember(key: "opacity", value: number(clip.opacity))
        ] + transform + [
            JSONMember(key: "animation", value: values.animation(clip.animation))
        ]))
    }

    private func content(_ content: ResolvedClipContent) -> [JSONMember] {
        switch content {
        case let .title(text):
            return [JSONMember(key: "title", value: values.text(text))]

        case let .shape(shape):
            return self.shape(shape)

        case let .adjustment(operations):
            return [JSONMember(key: "adjust", value: values.filter(operations))]

        case let .media(clip):
            let timing = clip.timing.map { timing in
                [
                    JSONMember(key: "in", value: .number(timing.in)),
                    JSONMember(key: "origin", value: .number(timing.origin)),
                    JSONMember(key: "out", value: .number(timing.out)),
                    JSONMember(key: "speed", value: .number(timing.speed)),
                    JSONMember(key: "loop", value: .bool(timing.loop))
                ]
            } ?? []

            return [JSONMember(key: "media", value: media(clip.media))] + timing
                + [JSONMember(key: "filter", value: values.filter(clip.filter))]
                + appearance(clip.appearance)
        }
    }

    // A shape's kind, its geometry as written and its outset, every key written and null where it has none, and how it
    // is drawn.
    private func shape(_ shape: ResolvedShape) -> [JSONMember] {
        let numbers = { (keyframes: [Keyframe<Double>]) in self.values.numbers(keyframes) }
        let stroke = shape.stroke.map { stroke in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "color", value: values.color(stroke.color)),
                JSONMember(key: "width", value: .number(stroke.width)),
                JSONMember(key: "join", value: .string(stroke.join.rawValue)),
                JSONMember(key: "cap", value: .string(stroke.cap.rawValue)),
                JSONMember(key: "start", value: .string(stroke.start.rawValue)),
                JSONMember(key: "end", value: .string(stroke.end.rawValue))
            ]))
        }

        let geometry: (
            area: JSONValue,
            width: JSONValue,
            height: JSONValue,
            points: JSONValue,
            closed: JSONValue,
            outset: JSONValue
        ) = switch shape.geometry {
        case let .box(width, height, outset):
            (.null, numbers(width), numbers(height), .null, .null, .number(outset))

        case let .area(area, outset, _):
            (values.keyframes(area, value: values.rectangle), .null, .null, .null, .null, .number(outset))

        case let .points(points, isClosed, _):
            (.null, .null, .null, values.keyframes(points) { .array($0.map(values.point)) }, .bool(isClosed), .null)
        }

        return [
            JSONMember(key: "shape", value: .string(shape.kind.rawValue)),
            JSONMember(key: "area", value: geometry.area),
            JSONMember(key: "width", value: geometry.width),
            JSONMember(key: "height", value: geometry.height),
            JSONMember(key: "points", value: geometry.points),
            JSONMember(key: "closed", value: geometry.closed),
            JSONMember(key: "outset", value: geometry.outset),
            JSONMember(key: "radius", value: numbers(shape.radius)),
            JSONMember(key: "trim", value: values.keyframes(shape.trim) { trim in
                .array([.number(trim.start), .number(trim.end)])
            }),
            JSONMember(key: "fill", value: shape.fill.map(values.color) ?? .null),
            JSONMember(key: "stroke", value: stroke ?? .null),
            JSONMember(key: "shadow", value: shape.shadow.map(self.shadow) ?? .null)
        ]
    }

    // How a media clip's picture fills its box, its crop aside, which is written with the geometry.
    private func appearance(_ appearance: ResolvedMediaAppearance) -> [JSONMember] {
        [
            JSONMember(key: "conform", value: .string(appearance.conform.rawValue)),
            JSONMember(key: "radius", value: .number(appearance.radius)),
            JSONMember(key: "border", value: appearance.border.map(border) ?? .null),
            JSONMember(key: "shadow", value: appearance.shadow.map(shadow) ?? .null)
        ]
    }

    private func border(_ border: MediaBorder) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "width", value: .number(border.width)),
            JSONMember(key: "color", value: values.color(border.color))
        ]))
    }

    private func shadow(_ shadow: DropShadow) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "radius", value: .number(shadow.radius)),
            JSONMember(key: "offset", value: values.point(shadow.offset)),
            JSONMember(key: "color", value: values.color(shadow.color))
        ]))
    }

    private func sound(_ sound: ResolvedSound) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(sound.place)),
            JSONMember(key: "media", value: sound.media.map { .object(JSONObject(members: values.media($0))) } ?? .null),
            JSONMember(key: "nested", value: .array(sound.nested.map(self.sound))),
            JSONMember(key: "in", value: .number(sound.in)),
            JSONMember(key: "origin", value: .number(sound.origin)),
            JSONMember(key: "out", value: .number(sound.out)),
            JSONMember(key: "speed", value: .number(sound.speed)),
            JSONMember(key: "loop", value: .bool(sound.loop)),
            JSONMember(key: "start", value: .number(sound.start)),
            JSONMember(key: "end", value: .number(sound.end)),
            JSONMember(key: "audible", value: values.range(sound.audible)),
            JSONMember(key: "volume", value: values.numbers(sound.volume)),
            JSONMember(key: "fadeIn", value: values.range(sound.fadeIn)),
            JSONMember(key: "fadeOut", value: values.range(sound.fadeOut)),
            JSONMember(key: "incoming", value: values.range(sound.incoming)),
            JSONMember(key: "outgoing", value: values.range(sound.outgoing))
        ]))
    }

    private func media(_ content: ResolvedMediaContent) -> JSONValue {
        switch content {
        case let .pinned(media):
            .object(JSONObject(members: values.media(media)))

        case let .nested(nested):
            document(nested)
        }
    }

    private func crops(_ keyframes: [Keyframe<Crop>]) -> JSONValue {
        values.keyframes(keyframes) { values.rectangle($0.rectangle) }
    }

    // Track frames are media frames, so they keep the media time of each frame, as `frames` does.
    // `clip` is the id of the matte clip, which keeps its own entry.
    private func trackMatte(_ matte: TrackMatte) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "clip", value: .string(matte.clip)),
            JSONMember(key: "mode", value: .string(matte.mode.rawValue)),
            JSONMember(key: "invert", value: .bool(matte.isInverted))
        ]))
    }

    private func track(_ track: ResolvedTrack) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "target", value: values.rectangle(track.target)),
            JSONMember(key: "time", value: .number(track.mediaTime)),
            JSONMember(key: "frames", value: .array(track.frames.map { frame in
                .object(JSONObject(members: [
                    JSONMember(key: "time", value: .number(frame.time)),
                    JSONMember(key: "value", value: values.rectangle(frame.rectangle))
                ]))
            }))
        ]))
    }

    // A cover's or matte's media keys, then its length in media seconds.
    private func transitionMedia(_ media: ResolvedTransitionMedia) -> [JSONMember] {
        values.media(media.media) + [JSONMember(key: "duration", value: .number(media.duration))]
    }

    private func transition(_ transition: ResolvedTransition) -> JSONValue {
        let span = { (span: Span) in JSONValue.object(JSONObject(members: values.span(span))) }
        let cover = transition.cover.map { cover in
            let source = switch cover.source {
            case let .color(color):
                [JSONMember(key: "color", value: values.color(color))]

            case let .media(media):
                transitionMedia(media)
            }

            return JSONValue.object(JSONObject(members: source + values.span(cover.span)))
        }
        let matte = transition.matte.map { matte in
            JSONValue.object(JSONObject(members: transitionMedia(matte.media) + [
                JSONMember(key: "softness", value: .number(matte.softness)),
                JSONMember(key: "invert", value: .bool(matte.isInverted)),
                JSONMember(key: "ease", value: values.ease(matte.ease))
            ]))
        }

        return .object(JSONObject(members: [
            JSONMember(key: "start", value: .number(transition.start)),
            JSONMember(key: "end", value: .number(transition.end)),
            JSONMember(key: "over", value: .string(transition.over.rawValue)),
            JSONMember(key: "incoming", value: transition.incoming.map(span) ?? .null),
            JSONMember(key: "outgoing", value: transition.outgoing.map(span) ?? .null),
            JSONMember(key: "cover", value: cover ?? .null),
            JSONMember(key: "matte", value: matte ?? .null)
        ]))
    }
}
