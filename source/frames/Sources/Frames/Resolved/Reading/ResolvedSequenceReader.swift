//
//  ResolvedSequenceReader.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads a resolved sequence as `ResolvedSequenceWriter` writes it: its format, its storyline, its other clips and every
// source of sound. A nested document in place of a file is read as a sequence of its own. Which keys an entry
// holds follows from what it is, so a key resolve writes only for another kind of entry stops by its name.
struct ResolvedSequenceReader: Sendable {
    // MARK: - Property
    static let keys = ["kind", "format", "storyline", "clips", "audio"]

    // The keys every clips entry may hold besides what it draws.
    private static let clipKeys = [
        "place", "id", "start", "end", "lane", "storyline", "parented", "area", "size", "position", "anchor", "crop",
        "track", "label", "opacity", "scale", "rotation", "blend", "animation"
    ]

    // The keys of every kind of content, which a clip is first checked against before its own kind is known.
    private static let contentKeys = [
        "title", "shape", "width", "radius", "color", "side", "length", "head", "adjust", "media", "in", "origin",
        "out", "speed", "loop", "filter", "conform", "border", "shadow"
    ]

    private static let shapeNames = ["box", "fill", "dim", "arrow"]

    private let values = ResolvedValueReader()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // A document, with `extraKeys` beside a sequence's own: `resolved` on the outermost one.
    func document(
        _ value: PlacedJSONValue,
        extraKeys: [String] = []
    ) throws -> ResolvedSequence {
        let kind = try values.documentKind(value)

        return try sequence(value.object(kind: kind, keys: Self.keys + extraKeys))
    }

    func sequence(_ object: PlacedJSONObject) throws -> ResolvedSequence {
        ResolvedSequence(
            format: try format(object.member("format")),
            storyline: try object.member("storyline").elements().map(storyline),
            clips: try object.member("clips").elements().map(clip),
            audio: try object.member("audio").elements().map(sound)
        )
    }

    // MARK: - Private
    private func format(_ value: PlacedJSONValue) throws -> ResolvedFormat {
        let format = try value.object(
            kind: "format",
            keys: ["size", "fps", "duration", "background", "content", "conform"]
        )

        return ResolvedFormat(
            size: try values.size(format.member("size")),
            fps: try format.member("fps").number(),
            duration: try format.member("duration").number(),
            background: try values.color(format.member("background")),
            content: try values.rectangle(format.member("content")),
            conform: try conform(format.member("conform"))
        )
    }

    private func storyline(_ value: PlacedJSONValue) throws -> ResolvedStorylineClip {
        let entry = try value.object(kind: "storyline clip", keys: [
            "place", "id", "media", "solid", "in", "out", "speed", "start", "end", "crop", "track", "filter",
            "transition"
        ])

        return ResolvedStorylineClip(
            place: try entry.member("place").string(),
            id: try entry.member("id").optional { try $0.string() },
            media: try entry.member("media").optional(media),
            solid: try entry.member("solid").optional(values.color),
            in: try entry.member("in").number(),
            out: try entry.member("out").number(),
            speed: try entry.member("speed").number(),
            start: try entry.member("start").number(),
            end: try entry.member("end").number(),
            crop: try values.crops(entry.member("crop")),
            track: try entry.member("track").optional(track),
            filter: try values.filter(entry.member("filter")),
            transition: try entry.member("transition").optional(transition)
        )
    }

    // What a clip draws decides the keys it holds: its content's, then scale and rotation for a title or a media
    // clip and a blend mode for anything but an adjustment.
    private func clip(_ value: PlacedJSONValue) throws -> ResolvedClip {
        let written = try value.object(kind: "clip", keys: Self.clipKeys + Self.contentKeys)
        let contentKeys = try self.contentKeys(of: written)
        let isTransformed = written.contains("title") || written.contains("media")
        let isBlended = !written.contains("adjust")
        let clip = try value.object(
            kind: "clip",
            keys: Self.clipKeys.filter { key in
                (key != "scale" && key != "rotation" || isTransformed) && (key != "blend" || isBlended)
            } + contentKeys
        )
        let size = try clip.member("size")
        let position = try clip.member("position")
        let anchor = try clip.member("anchor")
        let box: ResolvedBox? = if size.isNull && position.isNull && anchor.isNull {
            nil
        } else {
            ResolvedBox(
                size: try values.size(size),
                position: try values.keyframes(position, read: values.point),
                anchor: try values.point(anchor)
            )
        }

        return ResolvedClip(
            place: try clip.member("place").string(),
            id: try clip.member("id").optional { try $0.string() },
            content: try content(of: clip),
            start: try clip.member("start").number(),
            end: try clip.member("end").number(),
            lane: try clip.member("lane").optional { try $0.integer() },
            storyline: try clip.member("storyline").optional { try $0.integer() },
            isParented: try clip.member("parented").bool(),
            area: try clip.member("area").optional { try values.keyframes($0, read: values.rectangle) },
            box: box,
            crop: try clip.member("crop").optional(values.crops),
            track: try clip.member("track").optional(track),
            label: try clip.member("label").optional(label),
            opacity: try values.numbers(clip.member("opacity")),
            scale: isTransformed ? try values.numbers(clip.member("scale")) : nil,
            rotation: isTransformed ? try values.numbers(clip.member("rotation")) : nil,
            blend: isBlended ? try clip.member("blend").string() : nil,
            animation: try values.animation(clip.member("animation"))
        )
    }

    // A title, a shape by its name, an adjustment or a media clip, timed when it has `in`.
    private func contentKeys(of clip: PlacedJSONObject) throws -> [String] {
        if clip.contains("title") {
            return ["title"]
        }
        if clip.contains("shape") {
            let name = try clip.member("shape").name(among: Self.shapeNames) { Self.shapeNames.contains($0) ? $0 : nil }

            return switch name {
            case "box":
                ["shape", "width", "radius", "color"]

            case "arrow":
                ["shape", "side", "length", "width", "head", "color"]

            default:
                ["shape", "color"]
            }
        }
        if clip.contains("adjust") {
            return ["adjust"]
        }
        if clip.contains("media") {
            let timing = clip.contains("in") ? ["in", "origin", "out", "speed", "loop"] : []

            return ["media"] + timing + ["filter", "conform", "radius", "border", "shadow"]
        }

        throw ModelError.missingKey(place: clip.place, kind: clip.kind, keys: ["title", "shape", "adjust", "media"])
    }

    private func content(of clip: PlacedJSONObject) throws -> ResolvedClipContent {
        if clip.contains("title") {
            return .title(try values.text(clip.member("title")))
        }
        if clip.contains("shape") {
            return .shape(try shape(clip))
        }
        if clip.contains("adjust") {
            return .adjustment(try values.filter(clip.member("adjust")))
        }

        let timing: ResolvedMediaTiming? = if clip.contains("in") {
            ResolvedMediaTiming(
                in: try clip.member("in").number(),
                origin: try clip.member("origin").number(),
                out: try clip.member("out").number(),
                speed: try clip.member("speed").number(),
                loop: try clip.member("loop").bool()
            )
        } else {
            nil
        }

        return .media(ResolvedMediaClip(
            media: try media(clip.member("media")),
            timing: timing,
            filter: try values.filter(clip.member("filter")),
            appearance: ResolvedMediaAppearance(
                conform: try conform(clip.member("conform")),
                radius: try clip.member("radius").number(),
                border: try clip.member("border").optional { value in
                    let border = try value.object(keys: ["width", "color"])

                    return MediaBorder(
                        width: try border.member("width").number(),
                        color: try values.color(border.member("color"))
                    )
                },
                shadow: try clip.member("shadow").optional { value in
                    let shadow = try value.object(keys: ["radius", "offset", "color"])

                    return MediaShadow(
                        radius: try shadow.member("radius").number(),
                        offset: try values.point(shadow.member("offset")),
                        color: try values.color(shadow.member("color"))
                    )
                }
            )
        ))
    }

    private func shape(_ clip: PlacedJSONObject) throws -> ShapeDrawing {
        let number = { (key: String) in try clip.member(key).number() }
        let color = try values.color(clip.member("color"))

        switch try clip.member("shape").string() {
        case "box":
            return .box(width: try number("width"), radius: try number("radius"), color: color)

        case "fill":
            return .fill(color: color)

        case "dim":
            return .dim(color: color)

        default:
            return .arrow(
                side: try side(clip.member("side")),
                length: try number("length"),
                width: try number("width"),
                head: try number("head"),
                color: color
            )
        }
    }

    private func label(_ value: PlacedJSONValue) throws -> ResolvedLabel {
        let label = try value.object(kind: "label", keys: ["side", "at", "text", "animation"])

        return ResolvedLabel(
            side: try side(label.member("side")),
            at: try label.member("at").number(),
            text: try values.text(label.member("text")),
            animation: try values.animation(label.member("animation"))
        )
    }

    private func sound(_ value: PlacedJSONValue) throws -> ResolvedSound {
        let sound = try value.object(kind: "audio", keys: [
            "place", "media", "nested", "in", "origin", "out", "speed", "loop", "start", "end", "audible", "volume",
            "fadeIn", "fadeOut", "incoming", "outgoing"
        ])
        let range = { (key: String) in try sound.member(key).optional(values.range) }

        return ResolvedSound(
            place: try sound.member("place").string(),
            media: try sound.member("media").optional(values.media),
            nested: try sound.member("nested").elements().map(self.sound),
            in: try sound.member("in").number(),
            origin: try sound.member("origin").number(),
            out: try sound.member("out").number(),
            speed: try sound.member("speed").number(),
            loop: try sound.member("loop").bool(),
            start: try sound.member("start").number(),
            end: try sound.member("end").number(),
            audible: try values.range(sound.member("audible")),
            volume: try values.numbers(sound.member("volume")),
            fadeIn: try range("fadeIn"),
            fadeOut: try range("fadeOut"),
            incoming: try range("incoming"),
            outgoing: try range("outgoing")
        )
    }

    // Pinned media, or a nested sequence, which names its `kind`.
    private func media(_ value: PlacedJSONValue) throws -> ResolvedMediaContent {
        guard value.value.objectValue?.contains("kind") == true else { return .pinned(try values.media(value)) }

        return .nested(try document(value))
    }

    private func track(_ value: PlacedJSONValue) throws -> ResolvedTrack {
        let track = try value.object(kind: "track", keys: ["target", "time", "band", "frames"])

        return ResolvedTrack(
            target: try values.rectangle(track.member("target")),
            mediaTime: try track.member("time").number(),
            isBand: try track.member("band").bool(),
            frames: try track.member("frames").elements().map { element in
                let frame = try element.object(keys: ["time", "value"])

                return TrackedFrame(
                    time: try frame.member("time").number(),
                    rectangle: try values.rectangle(frame.member("value"))
                )
            }
        )
    }

    private func transition(_ value: PlacedJSONValue) throws -> ResolvedTransition {
        let transition = try value.object(
            kind: "transition",
            keys: ["start", "end", "over", "incoming", "outgoing", "cover", "matte"]
        )

        return ResolvedTransition(
            start: try transition.member("start").number(),
            end: try transition.member("end").number(),
            over: try transition.member("over").name(among: ["incoming", "outgoing"], TransitionOrder.init),
            incoming: try transition.member("incoming").optional(values.span),
            outgoing: try transition.member("outgoing").optional(values.span),
            cover: try transition.member("cover").optional(cover),
            matte: try transition.member("matte").optional(matte)
        )
    }

    // A colour, or media with its length, then the span.
    private func cover(_ value: PlacedJSONValue) throws -> ResolvedCover {
        let isColor = value.value.objectValue?.contains("color") == true
        let sourceKeys = isColor ? ["color"] : ResolvedValueReader.mediaKeys + ["duration"]
        let cover = try value.object(kind: "cover", keys: sourceKeys + ResolvedValueReader.spanKeys)
        let source: ResolvedCoverSource = isColor
            ? .color(try values.color(cover.member("color")))
            : .media(try transitionMedia(cover))

        return ResolvedCover(source: source, span: try values.span(cover))
    }

    private func matte(_ value: PlacedJSONValue) throws -> ResolvedMatte {
        let matte = try value.object(
            kind: "matte",
            keys: ResolvedValueReader.mediaKeys + ["duration", "softness", "invert", "ease"]
        )

        return ResolvedMatte(
            media: try transitionMedia(matte),
            softness: try matte.member("softness").number(),
            isInverted: try matte.member("invert").bool(),
            ease: try values.ease(matte.member("ease"))
        )
    }

    private func transitionMedia(_ object: PlacedJSONObject) throws -> ResolvedTransitionMedia {
        ResolvedTransitionMedia(media: try values.media(object), duration: try object.member("duration").number())
    }

    private func conform(_ value: PlacedJSONValue) throws -> Conform {
        try value.name(among: ["fit", "fill"], Conform.init)
    }

    private func side(_ value: PlacedJSONValue) throws -> Side {
        try value.name(among: ["left", "right", "top", "bottom"], Side.init)
    }
}
