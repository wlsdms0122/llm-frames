//
//  ResolvedSequenceWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes a resolved sequence as the members of its resolved document after `kind`: its format, its storyline, its
// other clips in document order, every source of sound, and its own audio filter, its bus's chain. A nested document
// is written in place of a file.
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
            JSONMember(key: "audio", value: .array(sequence.audio.map(sound))),
            JSONMember(key: "audioFilter", value: values.timed(sequence.audioFilter))
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
            JSONMember(key: "peak", value: format.peak.map { .number($0) } ?? .null),
            JSONMember(key: "compositing", value: .string(format.compositing.rawValue)),
            JSONMember(key: "motionBlur", value: shutter(format.shutter))
        ]))
    }

    private func shutter(_ shutter: Shutter) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "shutterAngle", value: .number(shutter.angle)),
            JSONMember(key: "shutterPhase", value: .number(shutter.phase)),
            JSONMember(key: "samplesPerFrame", value: .number(Double(shutter.samplesPerFrame)))
        ]))
    }

    // An entry's kind is `media` or `solid`. An entry with media writes its corner pin after its anchor, and one with a
    // corner pin writes its box's size and its position, anchor, scale and rotation as null. A solid writes no corner
    // pin.
    private func storyline(_ entry: ResolvedStorylineClip) -> JSONValue {
        let box: ResolvedBox?
        let cornerPin: JSONValue
        let scale: JSONValue
        let rotation: JSONValue
        switch entry.placement {
        case let .transform(placed, scales, rotations):
            box = placed
            cornerPin = .null
            scale = values.scales(scales)
            rotation = values.numbers(rotations)

        case let .cornerPin(pin):
            box = nil
            cornerPin = values.followed(pin.points) { points in .array(points.corners.map(values.geometryPoint)) }
            scale = .null
            rotation = .null
        }
        let shown: ResolvedStorylineMedia? = if case let .media(media) = entry.content { media } else { nil }
        let color: [Keyframe<Color>]? = if case let .solid(color) = entry.content { color } else { nil }

        return .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(entry.place)),
            JSONMember(key: "id", value: entry.id.map(JSONValue.string) ?? .null),
            JSONMember(key: "kind", value: .string(shown == nil ? "solid" : "media")),
            JSONMember(key: "media", value: shown.map { media($0.media) } ?? .null),
            JSONMember(key: "color", value: color.map { values.keyframes($0, value: values.color) } ?? .null),
            JSONMember(key: "colorSpace", value: shown?.colorSpace.map { .string($0.rawValue) } ?? .null),
            JSONMember(key: "toneMap", value: shown?.isToneMapped.map(JSONValue.bool) ?? .null),
            JSONMember(key: "in", value: .number(entry.in)),
            JSONMember(key: "out", value: .number(entry.out)),
            JSONMember(key: "speed", value: .number(entry.speed)),
            JSONMember(key: "timeRemap", value: shown?.timeRemap.map(values.numbers) ?? .null),
            JSONMember(key: "start", value: .number(entry.start)),
            JSONMember(key: "end", value: .number(entry.end)),
            JSONMember(key: "size", value: values.size(entry.placement.size)),
            JSONMember(
                key: "position",
                value: box.map { values.followed($0.position, value: values.geometryPoint) } ?? .null
            ),
            JSONMember(key: "anchor", value: box.map { values.point($0.anchor) } ?? .null)
        ] + (shown == nil ? [] : [JSONMember(key: "cornerPin", value: cornerPin)]) + [
            JSONMember(key: "crop", value: crops(entry.crop)),
            JSONMember(key: "mask", value: values.masks(entry.mask)),
            JSONMember(key: "trackMatte", value: entry.trackMatte.map(trackMatte) ?? .null),
            JSONMember(key: "track", value: entry.track.map(track) ?? .null),
            JSONMember(key: "opacity", value: values.numbers(entry.opacity)),
            JSONMember(key: "scale", value: scale),
            JSONMember(key: "rotation", value: rotation),
            JSONMember(key: "blend", value: .string(entry.blend)),
            JSONMember(key: "motionBlur", value: .bool(entry.isMotionBlurred)),
            JSONMember(key: "filter", value: values.timed(entry.filter)),
            JSONMember(key: "radius", value: values.timed(entry.radius)),
            JSONMember(key: "border", value: values.timed(entry.border)),
            JSONMember(key: "shadow", value: values.timed(entry.shadow)),
            JSONMember(key: "transition", value: entry.transition.map(transition) ?? .null)
        ]))
    }

    // What a clip draws comes after its id and its kind, a media clip's timing, filter and appearance with it, and a shape's or a
    // null's geometry and appearance. Scale, rotation and a corner pin belong to anything drawn but an adjustment, and a
    // clip with a corner pin writes its box's size and its position, anchor, scale and rotation as null. A shape or a
    // null placed by its geometry writes its position and anchor where a box would, and its area with its own keys. A
    // null holds no key of how a picture is drawn or composited: no lane, corner pin, crop, mask, track matte, opacity
    // or blend.
    private func clip(_ clip: ResolvedClip) -> JSONValue {
        let number = { (keyframes: [Keyframe<Double>]) in values.numbers(keyframes) }
        let isAdjustment = if case .adjustment = clip.content { true } else { false }
        let placed = placed(clip.content)
        let scaleAndRotation = isAdjustment ? [] : [
            JSONMember(key: "scale", value: placed.transform.map { values.scales($0.scale) } ?? .null),
            JSONMember(key: "rotation", value: placed.transform.map { number($0.rotation) } ?? .null)
        ]
        let cornerPin = placed.cornerPin.map { pin in
            values.followed(pin.points) { points in .array(points.corners.map(values.geometryPoint)) }
        }
        let placement: GeometryPlacement? = switch clip.content {
        case let .picture(.shape(shape), _, _):
            shape.geometry.placement

        case let .null(null):
            null.geometry.shape.placement

        case .picture, .adjustment:
            nil
        }
        let position = placed.box?.position ?? placement?.position
        let anchor = placed.box.map { values.point($0.anchor) } ?? placement?.anchor.map(values.geometryAnchor)
        let box = [
            JSONMember(key: "size", value: (placed.box?.size ?? placed.cornerPin?.size).map(values.size) ?? .null),
            JSONMember(key: "position", value: position.map { values.followed($0, value: values.geometryPoint) } ?? .null),
            JSONMember(key: "anchor", value: anchor ?? .null)
        ]
        let track = JSONMember(key: "track", value: clip.track.map(self.track) ?? .null)
        let head = [
            JSONMember(key: "place", value: .string(clip.place)),
            JSONMember(key: "id", value: clip.id.map(JSONValue.string) ?? .null),
            JSONMember(key: "kind", value: .string(kind(of: clip.content)))
        ]
        let window = [
            JSONMember(key: "start", value: .number(clip.start)),
            JSONMember(key: "end", value: .number(clip.end))
        ]
        let parent = [
            JSONMember(key: "storyline", value: clip.storyline.map { .number(Double($0)) } ?? .null),
            JSONMember(key: "parent", value: clip.parent.map(JSONValue.string) ?? .null)
        ]
        let tail = [
            JSONMember(key: "motionBlur", value: .bool(clip.isMotionBlurred)),
            JSONMember(key: "animation", value: values.animation(clip.animation))
        ]

        // A picture and an adjustment write their content, their crop and their corner pin where they take one.
        let drawn = { (content: [JSONMember], cornerPin: [JSONMember], crop: FollowedValue<Crop>?, composite: ResolvedComposite) in
            let geometry = box + cornerPin + [
                JSONMember(key: "crop", value: crop.map(crops) ?? .null),
                JSONMember(key: "mask", value: values.masks(composite.mask)),
                JSONMember(key: "trackMatte", value: composite.trackMatte.map(trackMatte) ?? .null),
                track
            ]

            return JSONValue.object(JSONObject(members: head + content + window + [
                JSONMember(key: "lane", value: .number(Double(composite.lane)))
            ] + parent + geometry + [
                JSONMember(key: "opacity", value: number(composite.opacity))
            ] + scaleAndRotation + [
                JSONMember(key: "blend", value: .string(composite.blend))
            ] + tail))
        }

        switch clip.content {
        case let .picture(picture, _, composite):
            let pin = [JSONMember(key: "cornerPin", value: cornerPin ?? .null)]
            return drawn(content(picture), pin, crop(of: picture), composite)

        case let .adjustment(filter, _, composite):
            return drawn([JSONMember(key: "adjust", value: values.timed(filter))], [], nil, composite)

        case let .null(null):
            return .object(JSONObject(
                members: head + self.null(null) + window + parent + box + [track] + scaleAndRotation + tail
            ))
        }
    }

    // A media clip's crop, nil for every other picture, whose entry writes it as null.
    private func crop(of picture: ResolvedPicture) -> FollowedValue<Crop>? {
        guard case let .media(media) = picture else { return nil }
        return media.crop
    }

    // How a clip is placed, in the keys its entry writes: the transform of anything drawn but an adjustment where no
    // corner pin places it, with the box it holds, the corner pin of a picture one places, and an adjustment's box.
    private func placed(
        _ content: ResolvedClipContent
    ) -> (transform: ResolvedTransform?, cornerPin: ResolvedCornerPin?, box: ResolvedBox?) {
        switch content {
        case let .picture(_, .transform(transform), _):
            (transform, nil, transform.box)

        case let .null(null):
            (null.transform, nil, null.transform.box)

        case let .picture(_, .cornerPin(cornerPin), _):
            (nil, cornerPin, nil)

        case let .adjustment(_, box, _):
            (nil, nil, box)
        }
    }

    // The clip's kind as its document names it.
    private func kind(of content: ResolvedClipContent) -> String {
        switch content {
        case .picture(.title, _, _):
            "title"

        case let .picture(.shape(shape), _, _):
            shape.kind.rawValue

        case .adjustment:
            "adjustment"

        case .picture(.media, _, _):
            "media"

        case .null:
            "null"
        }
    }

    private func content(_ content: ResolvedPicture) -> [JSONMember] {
        switch content {
        case let .title(text):
            return [JSONMember(key: "title", value: values.text(text))]

        case let .shape(shape):
            return self.shape(shape)

        case let .media(clip):
            let timing = clip.timing.map(self.timing) ?? []

            return [JSONMember(key: "media", value: media(clip.media))] + timing
                + [JSONMember(key: "filter", value: values.timed(clip.filter))]
                + appearance(of: clip)
        }
    }

    // A null's geometry as a rect's entry writes it, `area` or `width` and `height`, the other keys null.
    private func null(_ null: ResolvedNull) -> [JSONMember] {
        let geometry: (area: JSONValue, width: JSONValue, height: JSONValue) = switch null.geometry {
        case let .box(width, height):
            (.null, values.numbers(width), values.numbers(height))

        case let .area(area, _):
            (values.followed(area, value: values.geometryArea), .null, .null)
        }

        return [
            JSONMember(key: "area", value: geometry.area),
            JSONMember(key: "width", value: geometry.width),
            JSONMember(key: "height", value: geometry.height)
        ]
    }

    // A shape's geometry as written and its outset, every key written and null where it has none, and how it
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
            (values.followed(area, value: values.geometryArea), .null, .null, .null, .null, values.timed(outset))

        case let .points(points, isClosed, _):
            (.null, .null, .null, .array(points.map(values.vertex)), .bool(isClosed), .null)
        }

        return [
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
            JSONMember(key: "media", value: media(of: sound.source)),
            JSONMember(key: "nested", value: nested(of: sound.source)),
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

    // A sound's pinned media, `null` for a nested sequence.
    private func media(of source: ResolvedSoundSource) -> JSONValue {
        guard case let .pinned(media) = source else { return .null }

        return values.media(media)
    }

    // A nested sequence's sound as its resolved sequence writes it, its audio entries and its own audio filter, `null`
    // for a media file.
    private func nested(of source: ResolvedSoundSource) -> JSONValue {
        guard case let .nested(nested, audioFilter) = source else { return .null }

        return .object(JSONObject(members: [
            JSONMember(key: "audio", value: .array(nested.map(self.sound))),
            JSONMember(key: "audioFilter", value: values.timed(audioFilter))
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
            values.media(media)

        case let .nested(nested):
            document(nested)
        }
    }

    private func crops(_ crop: FollowedValue<Crop>) -> JSONValue {
        values.followed(crop) { values.rectangle($0.rectangle) }
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
            JSONMember(key: "media", value: values.media(resolved.media)),
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

    // A cover's or matte's pinned media under `media`, its colour space, then its length in media seconds.
    private func transitionMedia(_ media: ResolvedTransitionMedia) -> [JSONMember] {
        [
            JSONMember(key: "media", value: values.media(media.media)),
            JSONMember(key: "colorSpace", value: media.colorSpace.map { .string($0.rawValue) } ?? .null),
            JSONMember(key: "duration", value: .number(media.duration))
        ]
    }

    private func transition(_ transition: ResolvedTransition) -> JSONValue {
        let span = { (span: Span) in JSONValue.object(JSONObject(members: values.span(span))) }
        let cover = transition.cover.map { cover in
            let source = switch cover.source {
            case let .solid(color):
                [
                    JSONMember(key: "kind", value: .string("solid")),
                    JSONMember(key: "color", value: values.color(color))
                ]

            case let .media(media):
                [JSONMember(key: "kind", value: .string("media"))] + transitionMedia(media)
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
