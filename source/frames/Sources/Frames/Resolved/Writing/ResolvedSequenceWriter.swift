//
//  ResolvedSequenceWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes what resolve decided for a sequence as the members of its resolved document after `kind`: its format, its
// storyline, its other clips in document order, and every source of sound. Instants are sequence time, media keeps
// `in`, `out` and `speed` in media time, and a compound clip, a template instance or a document met as media carries
// its nested resolved document in place of a file. Audio clips are drawn by nothing, so they are written as sound only.
struct ResolvedSequenceWriter: Sendable {
    // MARK: - Property
    private let values: ResolvedValueWriter
    private let pictures: ResolvedPictureWriter
    private let conformer = CropConformer()

    // MARK: - Initializer
    init(values: ResolvedValueWriter) {
        self.values = values
        self.pictures = ResolvedPictureWriter(values: values)
    }

    // MARK: - Public
    func members(of plan: SequencePlan) throws -> [JSONMember] {
        let clips = try plan.time.clips.indices
            .filter { plan.time.clips[$0].kind != .media(.audio) }
            .map { try clip(at: $0, of: plan) }

        return [
            JSONMember(key: "format", value: format(plan.format)),
            JSONMember(key: "storyline", value: .array(try plan.time.storyline.indices.map { try storyline(at: $0, of: plan) })),
            JSONMember(key: "clips", value: .array(clips)),
            JSONMember(key: "audio", value: .array(try plan.sound.map(sound)))
        ]
    }

    // A nested document is written as a document of its own kind, without a version, which only the outermost carries.
    func document(_ plan: DocumentPlan) throws -> JSONValue {
        switch plan {
        case let .sequence(sequence):
            .object(JSONObject(members: [JSONMember(key: "kind", value: .string("sequence"))] + (try members(of: sequence))))

        case let .picture(picture):
            .object(JSONObject(members: [JSONMember(key: "kind", value: .string(picture.kind))]
                + (try pictures.members(of: picture, sequences: members))))
        }
    }

    // MARK: - Private
    private func format(_ format: FormatPlan) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "size", value: values.size(format.size)),
            JSONMember(key: "fps", value: .number(format.fps)),
            JSONMember(key: "duration", value: .number(format.duration)),
            JSONMember(key: "background", value: values.color(format.background)),
            JSONMember(key: "content", value: values.rectangle(format.content)),
            JSONMember(key: "conform", value: .string(format.conform.rawValue))
        ]))
    }

    // A storyline clip's crop is conformed to the content rect, so evaluation fills that rect with it as it is. A clip
    // written without a crop shows its whole picture, conformed the same way. A solid has no media.
    private func storyline(
        at index: Int,
        of plan: SequencePlan
    ) throws -> JSONValue {
        let entry = plan.time.storyline[index]
        let geometry = plan.storyline[index]
        let format = plan.format
        let file = file(of: entry.source.media)
        let conform = { (rectangle: Rectangle) in
            values.rectangle(conformer.conformed(rectangle, to: format.content, by: format.conform))
        }
        let whole = geometry.nested?.size ?? file?.size ?? Size(width: format.content.width, height: format.content.height)
        let crop = geometry.crop.map { crop in
            values.keyframes(crop, instant: entry.instant) { conform($0.rectangle) }
        } ?? values.keyframes(
            PropertyValue<Rectangle>.value(Rectangle(x: 0, y: 0, width: whole.width, height: whole.height)),
            instant: entry.instant,
            value: conform
        )

        return .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(entry.place.description)),
            JSONMember(key: "id", value: entry.id.map(JSONValue.string) ?? .null),
            JSONMember(key: "media", value: try media(entry.source.media, nested: geometry.nested)),
            JSONMember(key: "solid", value: geometry.color.map(values.color) ?? .null),
            JSONMember(key: "in", value: .number(entry.source.clipRange.start)),
            JSONMember(key: "out", value: .number(entry.source.clipRange.end)),
            JSONMember(key: "speed", value: .number(entry.source.speed)),
            JSONMember(key: "start", value: .number(entry.edit.start)),
            JSONMember(key: "end", value: .number(entry.edit.end)),
            JSONMember(key: "crop", value: crop),
            JSONMember(key: "track", value: track(geometry.track)),
            JSONMember(key: "filter", value: try values.filter(geometry.filter)),
            JSONMember(key: "transition", value: try transition(entry.transition))
        ]))
    }

    // `parent` is the index of the storyline clip a parented clip is composited with. A title or a media clip carries
    // its box: `size`, `position` as its top left and `anchor` in its own pixels, `null` for a clip placed by an area.
    // Scale and rotation belong to a title or a media clip, and a blend mode to anything drawn but an adjustment.
    private func clip(
        at index: Int,
        of plan: SequencePlan
    ) throws -> JSONValue {
        let entry = plan.time.clips[index]
        let geometry = plan.clips[index]
        let appearance = geometry.appearance
        let instant = entry.instant
        let number = { (value: Double) in JSONValue.number(value) }

        var content: [JSONMember]
        switch entry.kind {
        case .title:
            content = [JSONMember(key: "title", value: try geometry.title.map(values.text) ?? .null)]

        case let .shape(shape):
            content = [JSONMember(key: "shape", value: .string(shape))] + (appearance.shape.map(drawing) ?? [])

        case .adjust, .solid:
            content = [JSONMember(key: "adjust", value: try values.filter(appearance.filter))]

        case .media:
            content = [JSONMember(key: "media", value: try media(entry.media, nested: geometry.nested))]
            if let timing = entry.timing {
                content += [
                    JSONMember(key: "in", value: .number(timing.map.in)),
                    JSONMember(key: "out", value: .number(timing.out)),
                    JSONMember(key: "speed", value: .number(timing.map.speed)),
                    JSONMember(key: "loop", value: .bool(timing.loop))
                ]
            }
            content.append(JSONMember(key: "filter", value: try values.filter(appearance.filter)))
            content += self.media(appearance.media)
        }

        let isTransformed = entry.kind == .title || entry.media != nil
        let transform = isTransformed
            ? [
                JSONMember(key: "scale", value: values.keyframes(appearance.scale, instant: instant, value: number)),
                JSONMember(key: "rotation", value: values.keyframes(appearance.rotation, instant: instant, value: number))
            ]
            : []
        let blend = entry.kind == .adjust ? [] : [JSONMember(key: "blend", value: .string(appearance.blend))]
        let label = try geometry.label.map { label in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "side", value: .string(label.side.rawValue)),
                JSONMember(key: "at", value: .number(label.instant)),
                JSONMember(key: "text", value: try values.text(label.text))
            ]))
        }
        let geometryMembers = [
            JSONMember(key: "area", value: geometry.area.map { values.keyframes($0, instant: instant) { values.rectangle($0.rectangle) } } ?? .null),
            JSONMember(key: "size", value: geometry.box.map { values.size($0.size) } ?? .null),
            JSONMember(key: "position", value: geometry.box.map { values.keyframes($0.position, instant: instant, value: values.point) } ?? .null),
            JSONMember(key: "anchor", value: geometry.box.map { values.point($0.anchor) } ?? .null),
            JSONMember(key: "crop", value: appearance.media.map { values.keyframes($0.crop, instant: instant, value: values.rectangle) } ?? .null),
            JSONMember(key: "track", value: track(geometry.track)),
            JSONMember(key: "label", value: label ?? .null)
        ]

        return .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(entry.place.description)),
            JSONMember(key: "id", value: entry.id.map(JSONValue.string) ?? .null)
        ] + content + [
            JSONMember(key: "start", value: .number(entry.visible.start)),
            JSONMember(key: "end", value: .number(entry.visible.end)),
            JSONMember(key: "lane", value: entry.lane.map { .number(Double($0)) } ?? .null),
            JSONMember(key: "parent", value: entry.isParented ? entry.storyline.map { .number(Double($0)) } ?? .null : .null)
        ] + geometryMembers + [
            JSONMember(key: "opacity", value: values.keyframes(appearance.opacity, instant: instant, value: number))
        ] + transform + blend + [
            JSONMember(key: "animation", value: animation(entry.animation))
        ]))
    }

    // A source of sound plays its media, or the sounds of its nested sequence on their own clock. Its volume holds
    // from the start of its range when it has no keyframes.
    private func sound(_ sound: SoundPlan) throws -> JSONValue {
        let file = file(of: sound.media)

        return .object(JSONObject(members: [
            JSONMember(key: "place", value: .string(sound.place.description)),
            JSONMember(key: "media", value: try file.map { .object(JSONObject(members: try values.media($0))) } ?? .null),
            JSONMember(key: "nested", value: .array(try sound.nested.map(self.sound))),
            JSONMember(key: "in", value: .number(sound.in)),
            JSONMember(key: "out", value: .number(sound.out)),
            JSONMember(key: "speed", value: .number(sound.speed)),
            JSONMember(key: "loop", value: .bool(sound.loop)),
            JSONMember(key: "start", value: .number(sound.range.start)),
            JSONMember(key: "end", value: .number(sound.range.end)),
            JSONMember(key: "audible", value: values.range(sound.audible)),
            JSONMember(key: "volume", value: values.keyframes(sound.volume, instant: sound.range.start) { .number($0) }),
            JSONMember(key: "fadeIn", value: values.range(sound.fadeIn)),
            JSONMember(key: "fadeOut", value: values.range(sound.fadeOut)),
            JSONMember(key: "incoming", value: values.range(sound.incoming)),
            JSONMember(key: "outgoing", value: values.range(sound.outgoing))
        ]))
    }

    private func media(
        _ media: ResolvedMedia?,
        nested: DocumentPlan?
    ) throws -> JSONValue {
        if let nested {
            return try document(nested)
        }
        guard let file = file(of: media) else { return .null }

        return .object(JSONObject(members: try values.media(file)))
    }

    // How a shape is drawn on its area, as an image's drawing step writes it, the area aside, which is written with the
    // geometry.
    private func drawing(_ drawing: ShapeDrawing) -> [JSONMember] {
        let number = { (key: String, number: Double) in JSONMember(key: key, value: .number(number)) }
        let color = { (color: Color) in JSONMember(key: "color", value: self.values.color(color)) }

        switch drawing {
        case let .box(width, radius, stroke):
            return [number("width", width), number("radius", radius), color(stroke)]

        case let .fill(fill), let .dim(fill):
            return [color(fill)]

        case let .arrow(side, length, width, head, stroke):
            return [
                JSONMember(key: "side", value: .string(side.rawValue)),
                number("length", length),
                number("width", width),
                number("head", head),
                color(stroke)
            ]
        }
    }

    // How a media clip's picture fills its box, its crop aside, which is written with the geometry.
    private func media(_ appearance: MediaAppearance?) -> [JSONMember] {
        guard let appearance else { return [] }

        let border = appearance.border.map { border in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "width", value: .number(border.width)),
                JSONMember(key: "color", value: values.color(border.color))
            ]))
        }
        let shadow = appearance.shadow.map { shadow in
            JSONValue.object(JSONObject(members: [
                JSONMember(key: "radius", value: .number(shadow.radius)),
                JSONMember(key: "offset", value: values.point(shadow.offset)),
                JSONMember(key: "color", value: values.color(shadow.color))
            ]))
        }

        return [
            JSONMember(key: "conform", value: .string(appearance.conform.rawValue)),
            JSONMember(key: "radius", value: .number(appearance.radius)),
            JSONMember(key: "border", value: border ?? .null),
            JSONMember(key: "shadow", value: shadow ?? .null)
        ]
    }

    private func file(of media: ResolvedMedia?) -> MediaFile? {
        guard case let .file(file) = media?.source else { return nil }

        return file
    }

    // Track frames are media frames, so they keep the media time of each frame, as `frames` does.
    private func track(_ track: Track?) -> JSONValue {
        guard let track else { return .null }

        return .object(JSONObject(members: [
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

    private func transition(_ transition: TransitionPlan?) throws -> JSONValue {
        guard let transition else { return .null }

        let definition = transition.definition
        let cover = try definition.cover.map { cover in
            let source = switch cover.source {
            case let .color(color):
                [JSONMember(key: "color", value: .string(color))]

            case let .media(media):
                try values.pinned(media)
            }

            return JSONValue.object(JSONObject(members: source + span(cover.span)))
        }
        let matte = try definition.matte.map { matte in
            JSONValue.object(JSONObject(members: try values.pinned(matte.media) + [
                JSONMember(key: "softness", value: .number(matte.softness)),
                JSONMember(key: "invert", value: .bool(matte.isInverted)),
                JSONMember(key: "ease", value: values.ease(matte.ease))
            ]))
        }

        return .object(JSONObject(members: [
            JSONMember(key: "start", value: .number(transition.range.start)),
            JSONMember(key: "end", value: .number(transition.range.end)),
            JSONMember(key: "over", value: .string(definition.over.rawValue)),
            JSONMember(key: "incoming", value: definition.incoming.map { .object(JSONObject(members: span($0))) } ?? .null),
            JSONMember(key: "outgoing", value: definition.outgoing.map { .object(JSONObject(members: span($0))) } ?? .null),
            JSONMember(key: "cover", value: cover ?? .null),
            JSONMember(key: "matte", value: matte ?? .null)
        ]))
    }

    private func animation(_ animation: AnimationPlan) -> JSONValue {
        let span = { (span: PresetSpan?, length: String) -> JSONValue in
            span.map { preset in
                .object(JSONObject(members: [JSONMember(key: length, value: .number(preset.span.length))] + self.span(preset.span.span)))
            } ?? .null
        }

        return .object(JSONObject(members: [
            JSONMember(key: "entrance", value: span(animation.entrance, "seconds")),
            JSONMember(key: "loop", value: span(animation.loop, "period")),
            JSONMember(key: "exit", value: span(animation.exit, "seconds"))
        ]))
    }

    // A key's values follow `t` in the order the motion properties are listed, so the same span is written the same way.
    private func span(_ span: Span) -> [JSONMember] {
        [
            JSONMember(key: "ease", value: values.ease(span.ease)),
            JSONMember(key: "revealFrom", value: .string(span.revealFrom.rawValue)),
            JSONMember(key: "keys", value: .array(span.keys.map { key in
                .object(JSONObject(members: [JSONMember(key: "t", value: .number(key.t))] + MotionProperty.allCases.compactMap { property in
                    key.values[property].map { JSONMember(key: property.rawValue, value: .number($0)) }
                }))
            }))
        ]
    }
}
