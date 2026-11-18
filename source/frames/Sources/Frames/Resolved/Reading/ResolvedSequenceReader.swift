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
        "place", "id", "start", "end", "lane", "storyline", "parent", "area", "size", "position", "anchor", "crop",
        "track", "opacity", "scale", "rotation", "blend", "animation"
    ]

    // The keys of every kind of content, which a clip is first checked against before its own kind is known.
    private static let contentKeys = [
        "title", "shape", "width", "height", "points", "closed", "outset", "radius", "trim", "fill", "stroke", "adjust",
        "media", "in", "origin", "out", "speed", "loop", "filter", "conform", "border", "shadow"
    ]

    private static let shapeKeys = [
        "shape", "area", "width", "height", "points", "closed", "outset", "radius", "trim", "fill", "stroke", "shadow"
    ]

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
        let format = try format(object.member("format"))
        let storyline = try object.member("storyline").elements().map(storyline)
        let written = try object.member("clips").elements()
        let clips = try written.map(clip)
        try checkParents(of: clips, places: written.map(\.place), storyline: storyline)

        return ResolvedSequence(
            format: format,
            storyline: storyline,
            clips: clips,
            audio: try object.member("audio").elements().map(sound)
        )
    }

    // MARK: - Private
    // Evaluation follows each parent chain to its end, so a parent that names no clip with a picture of the sequence,
    // or a chain that comes back to itself, stops here as it does in resolve. Audio clips are not among the clips.
    private func checkParents(
        of clips: [ResolvedClip],
        places: [Place],
        storyline: [ResolvedStorylineClip]
    ) throws {
        let parents = try clips.indices.map { index -> Int? in
            guard let id = clips[index].parent, !storyline.contains(where: { $0.id == id }) else { return nil }
            guard let parent = clips.firstIndex(where: { $0.id == id }) else {
                throw ResolveError.unknownParent(
                    place: places[index].appending(key: "parent"),
                    kind: kind(of: clips[index]),
                    id: id
                )
            }

            return parent
        }

        let finder = ParentFinder()
        for index in clips.indices {
            guard let cycle = finder.cycle(from: index, parents: parents) else { continue }

            throw ResolveError.parentCycle(
                place: places[cycle[0]].appending(key: "parent"),
                kind: kind(of: clips[cycle[0]]),
                ids: cycle.map { clips[$0].id ?? clips[$0].place }
            )
        }
    }

    private func kind(of clip: ResolvedClip) -> PlaceKind {
        .genericClip(clip.storyline == nil ? .sequence : .connected)
    }

    private func format(_ value: PlacedJSONValue) throws -> ResolvedFormat {
        let format = try value.object(
            kind: "format",
            keys: ["size", "fps", "duration", "background", "conform"]
        )

        return ResolvedFormat(
            size: try values.size(format.member("size")),
            fps: try format.member("fps").number(),
            duration: try format.member("duration").number(),
            background: try values.color(format.member("background")),
            conform: try conform(format.member("conform"))
        )
    }

    private func storyline(_ value: PlacedJSONValue) throws -> ResolvedStorylineClip {
        let entry = try value.object(kind: "storyline clip", keys: [
            "place", "id", "media", "solid", "in", "out", "speed", "start", "end", "size", "position", "anchor", "crop",
            "track", "opacity", "scale", "rotation", "blend", "filter", "radius", "border", "shadow", "transition"
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
            box: ResolvedBox(
                size: try values.size(entry.member("size")),
                position: try values.keyframes(entry.member("position"), read: values.point),
                anchor: try values.point(entry.member("anchor"))
            ),
            opacity: try values.numbers(entry.member("opacity")),
            scale: try values.numbers(entry.member("scale")),
            rotation: try values.numbers(entry.member("rotation")),
            blend: try entry.member("blend").string(),
            radius: try entry.member("radius").number(),
            border: try entry.member("border").optional(border),
            shadow: try entry.member("shadow").optional(shadow),
            transition: try entry.member("transition").optional(transition)
        )
    }

    // What a clip draws decides the keys it holds: its content's, then scale, rotation and a blend mode for anything
    // but an adjustment. A shape without `size` is placed by its geometry, and its `position` and `anchor` are its own.
    private func clip(_ value: PlacedJSONValue) throws -> ResolvedClip {
        let written = try value.object(kind: "clip", keys: Self.clipKeys + Self.contentKeys)
        let contentKeys = try self.contentKeys(of: written)
        let isTransformed = !written.contains("adjust")
        let clip = try value.object(
            kind: "clip",
            keys: Self.clipKeys.filter { key in
                isTransformed || key != "scale" && key != "rotation" && key != "blend"
            } + contentKeys
        )
        let size = try clip.member("size")
        let position = try clip.member("position")
        let anchor = try clip.member("anchor")
        let isShape = clip.contains("shape")
        let box: ResolvedBox? = if size.isNull && (isShape || position.isNull && anchor.isNull) {
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
            content: try content(of: clip, isPlacedByBox: box != nil),
            start: try clip.member("start").number(),
            end: try clip.member("end").number(),
            lane: try clip.member("lane").optional { try $0.integer() },
            storyline: try clip.member("storyline").optional { try $0.integer() },
            parent: try clip.member("parent").optional { try $0.string() },
            area: isShape ? nil : try clip.member("area").optional { try values.keyframes($0, read: values.rectangle) },
            box: box,
            crop: try clip.member("crop").optional(values.crops),
            track: try clip.member("track").optional(track),
            opacity: try values.numbers(clip.member("opacity")),
            scale: isTransformed ? try values.numbers(clip.member("scale")) : nil,
            rotation: isTransformed ? try values.numbers(clip.member("rotation")) : nil,
            blend: isTransformed ? try clip.member("blend").string() : nil,
            animation: try values.animation(clip.member("animation"))
        )
    }

    // A title, a shape by its name, an adjustment or a media clip, timed when it has `in`.
    private func contentKeys(of clip: PlacedJSONObject) throws -> [String] {
        if clip.contains("title") {
            return ["title"]
        }
        if clip.contains("shape") {
            return Self.shapeKeys
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

    private func content(
        of clip: PlacedJSONObject,
        isPlacedByBox: Bool
    ) throws -> ResolvedClipContent {
        if clip.contains("title") {
            return .title(try values.text(clip.member("title")))
        }
        if clip.contains("shape") {
            return .shape(try shape(clip, isPlacedByBox: isPlacedByBox))
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
                border: try clip.member("border").optional(border),
                shadow: try clip.member("shadow").optional(shadow)
            )
        ))
    }

    private func border(_ value: PlacedJSONValue) throws -> MediaBorder {
        let border = try value.object(keys: ["width", "color"])

        return MediaBorder(
            width: try border.member("width").number(),
            color: try values.color(border.member("color"))
        )
    }

    private func shadow(_ value: PlacedJSONValue) throws -> DropShadow {
        let shadow = try value.object(keys: ["radius", "offset", "color"])

        return DropShadow(
            radius: try shadow.member("radius").number(),
            offset: try values.point(shadow.member("offset")),
            color: try values.color(shadow.member("color"))
        )
    }

    // A shape's kind and geometry, then how it is drawn: a path by its points, a rect or an ellipse with a box by its
    // `width` and `height`, and one without by its area. One placed by its geometry carries its position and its
    // anchor point.
    private func shape(
        _ clip: PlacedJSONObject,
        isPlacedByBox: Bool
    ) throws -> ResolvedShape {
        let kind = try clip.member("shape").name(among: ShapeKind.allCases.map(\.rawValue), ShapeKind.init)
        let geometry: ShapeGeometry = if kind == .path {
            .points(
                try values.keyframes(clip.member("points")) { points in try points.elements().map(values.point) },
                isClosed: try clip.member("closed").bool(),
                placement: try placement(of: clip)
            )
        } else if isPlacedByBox {
            .box(
                width: try values.numbers(clip.member("width")),
                height: try values.numbers(clip.member("height")),
                outset: try clip.member("outset").number()
            )
        } else {
            .area(
                try values.keyframes(clip.member("area"), read: values.rectangle),
                outset: try clip.member("outset").number(),
                placement: try placement(of: clip)
            )
        }

        return ResolvedShape(
            kind: kind,
            geometry: geometry,
            radius: try values.numbers(clip.member("radius")),
            trim: try values.keyframes(clip.member("trim")) { value in
                let ends = try value.numbers()
                guard ends.count == 2 else { throw value.wrongType("[a, b]") }

                return Trim(start: ends[0], end: ends[1])
            },
            fill: try clip.member("fill").optional(values.color),
            stroke: try clip.member("stroke").optional(stroke),
            shadow: try clip.member("shadow").optional(shadow)
        )
    }

    private func placement(of clip: PlacedJSONObject) throws -> GeometryPlacement {
        GeometryPlacement(
            position: try clip.member("position").optional { value in try values.keyframes(value, read: values.point) },
            anchor: try clip.member("anchor").optional(values.point)
        )
    }

    private func stroke(_ value: PlacedJSONValue) throws -> PathStroke {
        let stroke = try value.object(kind: "stroke", keys: ["color", "width", "join", "cap", "start", "end"])
        let end = { (key: String) in
            try stroke.member(key).name(among: StrokeEnd.allCases.map(\.rawValue), StrokeEnd.init)
        }

        return PathStroke(
            width: try stroke.member("width").number(),
            color: try values.color(stroke.member("color")),
            join: try stroke.member("join").name(among: StrokeJoin.allCases.map(\.rawValue), StrokeJoin.init),
            cap: try stroke.member("cap").name(among: StrokeCap.allCases.map(\.rawValue), StrokeCap.init),
            start: try end("start"),
            end: try end("end")
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
        let track = try value.object(kind: "track", keys: ["target", "time", "frames"])

        return ResolvedTrack(
            target: try values.rectangle(track.member("target")),
            mediaTime: try track.member("time").number(),
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
}
