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
            JSONMember(key: "conform", value: .string(format.conform.rawValue)),
            JSONMember(key: "colorSpace", value: .string(format.colorSpace.rawValue)),
            JSONMember(key: "compositing", value: .string(format.compositing.rawValue))
        ]))
    }

    private func storyline(_ entry: ResolvedStorylineClip) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(entry.place)),
            JSONMember(key: "id", value: entry.id.map(JSONValue.string) ?? .null),
            JSONMember(key: "media", value: entry.media.map(media) ?? .null),
            JSONMember(key: "solid", value: entry.solid.map(values.color) ?? .null),
            JSONMember(key: "colorSpace", value: entry.colorSpace.map { .string($0.rawValue) } ?? .null),
            JSONMember(key: "toneMap", value: entry.isToneMapped.map(JSONValue.bool) ?? .null),
            JSONMember(key: "in", value: .number(entry.in)),
            JSONMember(key: "out", value: .number(entry.out)),
            JSONMember(key: "speed", value: .number(entry.speed)),
            JSONMember(key: "timeRemap", value: entry.timeRemap.map(values.numbers) ?? .null),
            JSONMember(key: "start", value: .number(entry.start)),
            JSONMember(key: "end", value: .number(entry.end)),
            JSONMember(key: "size", value: values.size(entry.box.size)),
            JSONMember(key: "position", value: values.keyframes(entry.box.position, value: values.geometryPoint)),
            JSONMember(key: "anchor", value: values.point(entry.box.anchor)),
            JSONMember(key: "crop", value: crops(entry.crop)),
            JSONMember(key: "mask", value: values.masks(entry.mask)),
            JSONMember(key: "trackMatte", value: entry.trackMatte.map(trackMatte) ?? .null),
            JSONMember(key: "track", value: entry.track.map(track) ?? .null),
            JSONMember(key: "opacity", value: values.numbers(entry.opacity)),
            JSONMember(key: "scale", value: values.scales(entry.scale)),
            JSONMember(key: "rotation", value: values.numbers(entry.rotation)),
            JSONMember(key: "blend", value: .string(entry.blend)),
            JSONMember(key: "filter", value: values.timed(entry.filter)),
            JSONMember(key: "radius", value: values.timed(entry.radius)),
            JSONMember(key: "border", value: values.timed(entry.border)),
            JSONMember(key: "shadow", value: values.timed(entry.shadow)),
            JSONMember(key: "transition", value: entry.transition.map(transition) ?? .null)
        ]))
    }

    // What a clip draws comes after its id, a media clip's timing, filter and appearance with it, and a shape's
    // geometry and appearance. Scale and rotation belong to anything drawn but an adjustment. A shape
    // placed by its geometry writes its position and anchor where a box would, and its area with its own keys.
    private func clip(_ clip: ResolvedClip) -> JSONValue {
        let number = { (keyframes: [Keyframe<Double>]) in values.numbers(keyframes) }
        let transform = [
            clip.scale.map { JSONMember(key: "scale", value: values.scales($0)) },
            clip.rotation.map { JSONMember(key: "rotation", value: number($0)) },
            JSONMember(key: "blend", value: .string(clip.blend))
        ].compactMap { $0 }
        let shape: ResolvedShape? = if case let .shape(shape) = clip.content { shape } else { nil }
        let placement = shape?.geometry.placement
        let position = clip.box?.position ?? placement?.position
        let anchor = clip.box.map { values.point($0.anchor) } ?? placement?.anchor.map(values.geometryAnchor)
        let geometry = [
            JSONMember(key: "size", value: clip.box.map { values.size($0.size) } ?? .null),
            JSONMember(key: "position", value: position.map { values.keyframes($0, value: values.geometryPoint) } ?? .null),
            JSONMember(key: "anchor", value: anchor ?? .null),
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

        case let .adjustment(filter):
            return [JSONMember(key: "adjust", value: values.timed(filter))]

        case let .media(clip):
            let timing = clip.timing.map(self.timing) ?? []

            return [JSONMember(key: "media", value: media(clip.media))] + timing
                + [JSONMember(key: "filter", value: values.timed(clip.filter))]
                + appearance(of: clip)
        }
    }

    // A shape's kind, its geometry as written and its outset, every key written and null where it has none, and how it
    // is drawn.
    private func shape(_ shape: ResolvedShape) -> [JSONMember] {
        let numbers = { (keyframes: [Keyframe<Double>]) in self.values.numbers(keyframes) }

        let geometry: (
            area: JSONValue,
            width: JSONValue,
            height: JSONValue,
            points: JSONValue,
            closed: JSONValue,
            outset: JSONValue
        ) = switch shape.geometry {
        case let .box(width, height, outset):
            (.null, numbers(width), numbers(height), .null, .null, values.timed(outset))

        case let .area(area, outset, _):
            (values.keyframes(area, value: values.geometryArea), .null, .null, .null, .null, values.timed(outset))

        case let .points(points, isClosed, _):
            (.null, .null, .null, values.keyframes(points) { .array($0.map(values.geometryPoint)) }, .bool(isClosed), .null)
        }

        return [
            JSONMember(key: "shape", value: .string(shape.kind.rawValue)),
            JSONMember(key: "area", value: geometry.area),
            JSONMember(key: "width", value: geometry.width),
            JSONMember(key: "height", value: geometry.height),
            JSONMember(key: "points", value: geometry.points),
            JSONMember(key: "closed", value: geometry.closed),
            JSONMember(key: "outset", value: geometry.outset),
            JSONMember(key: "radius", value: values.timed(shape.radius)),
            JSONMember(key: "trim", value: values.keyframes(shape.trim) { trim in
                .array([.number(trim.start), .number(trim.end)])
            }),
            JSONMember(key: "fill", value: values.timed(shape.fill)),
            JSONMember(key: "stroke", value: values.timed(shape.stroke)),
            JSONMember(key: "shadow", value: values.timed(shape.shadow))
        ]
    }

    // How a media clip's picture fills its box and how its pictures are read, its crop aside, which is written with the
    // geometry.
    private func appearance(of clip: ResolvedMediaClip) -> [JSONMember] {
        let appearance = clip.appearance

        return [
            JSONMember(key: "conform", value: .string(appearance.conform.rawValue)),
            JSONMember(key: "colorSpace", value: clip.colorSpace.map { .string($0.rawValue) } ?? .null),
            JSONMember(key: "toneMap", value: clip.isToneMapped.map(JSONValue.bool) ?? .null),
            JSONMember(key: "radius", value: values.timed(appearance.radius)),
            JSONMember(key: "border", value: values.timed(appearance.border)),
            JSONMember(key: "shadow", value: values.timed(appearance.shadow))
        ]
    }

    // A remapped clip's keys give the media time at every instant of its window, so it has no `in`, `out` or `loop`,
    // and its speed is 1.
    private func timing(_ timing: MediaTiming) -> [JSONMember] {
        switch timing {
        case let .played(range):
            [
                JSONMember(key: "in", value: .number(range.in)),
                JSONMember(key: "origin", value: .number(range.origin)),
                JSONMember(key: "out", value: .number(range.out)),
                JSONMember(key: "speed", value: .number(range.speed)),
                JSONMember(key: "loop", value: .bool(range.loop)),
                JSONMember(key: "timeRemap", value: .null)
            ]

        case let .remapped(origin, timeRemap):
            [
                JSONMember(key: "in", value: .null),
                JSONMember(key: "origin", value: .number(origin)),
                JSONMember(key: "out", value: .null),
                JSONMember(key: "speed", value: .number(1)),
                JSONMember(key: "loop", value: .null),
                JSONMember(key: "timeRemap", value: values.numbers(timeRemap))
            ]
        }
    }

    private func sound(_ sound: ResolvedSound) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(sound.place)),
            JSONMember(key: "media", value: sound.media.map { .object(JSONObject(members: values.media($0))) } ?? .null),
            JSONMember(key: "nested", value: .array(sound.nested.map(self.sound))),
            JSONMember(key: "in", value: .number(sound.played.in)),
            JSONMember(key: "origin", value: .number(sound.played.origin)),
            JSONMember(key: "out", value: .number(sound.played.out)),
            JSONMember(key: "speed", value: .number(sound.played.speed)),
            JSONMember(key: "loop", value: .bool(sound.played.loop)),
            JSONMember(key: "start", value: .number(sound.start)),
            JSONMember(key: "end", value: .number(sound.end)),
            JSONMember(key: "audible", value: values.range(sound.audible)),
            JSONMember(key: "volume", value: values.numbers(sound.volume)),
            JSONMember(key: "pan", value: values.numbers(sound.pan)),
            JSONMember(key: "fadeIn", value: values.range(sound.fadeIn)),
            JSONMember(key: "fadeOut", value: values.range(sound.fadeOut)),
            JSONMember(key: "incoming", value: sound.incoming.map(crossfade) ?? .null),
            JSONMember(key: "outgoing", value: sound.outgoing.map(crossfade) ?? .null),
            JSONMember(key: "audioFilter", value: values.timed(sound.audioFilter))
        ]))
    }

    // A transition as the sound it crossfades hears it, by its range and the curve its preset's `audio` names.
    private func crossfade(_ crossfade: Crossfade) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "start", value: .number(crossfade.range.start)),
            JSONMember(key: "end", value: .number(crossfade.range.end)),
            JSONMember(key: "audio", value: .string(crossfade.curve.rawValue))
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

    // `clip` is the id of the matte clip, which keeps its own entry.
    private func trackMatte(_ matte: TrackMatte) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "clip", value: .string(matte.clip)),
            JSONMember(key: "mode", value: .string(matte.mode.rawValue)),
            JSONMember(key: "invert", value: .bool(matte.isInverted))
        ]))
    }

    // Track frames are media frames, so they keep the media time of each frame, as `frames` does.
    private func track(_ resolved: ResolvedTrack) -> JSONValue {
        let track = resolved.track

        return .object(JSONObject(members: [
            JSONMember(key: "media", value: .object(JSONObject(members: values.media(resolved.media)))),
            JSONMember(key: "time", value: .number(track.mediaTime)),
            JSONMember(key: "target", value: values.quad(track.target)),
            JSONMember(key: "frames", value: .array(track.samples.map { sample in
                .object(JSONObject(members: [
                    JSONMember(key: "time", value: .number(sample.time)),
                    JSONMember(key: "quad", value: values.quad(sample.quad)),
                    JSONMember(key: "motion", value: values.numbers(sample.motion.transform.matrix))
                ]))
            }))
        ]))
    }

    // A cover's or matte's media keys, its colour space, then its length in media seconds.
    private func transitionMedia(_ media: ResolvedTransitionMedia) -> [JSONMember] {
        values.media(media.media) + [
            JSONMember(key: "colorSpace", value: media.colorSpace.map { .string($0.rawValue) } ?? .null),
            JSONMember(key: "duration", value: .number(media.duration))
        ]
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
