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
        "place", "id", "start", "end", "lane", "storyline", "parent", "size", "position", "anchor", "crop", "mask",
        "trackMatte", "track", "opacity", "scale", "rotation", "blend", "animation"
    ]

    // The keys of every kind of content, which a clip is first checked against before its own kind is known.
    private static let contentKeys = [
        "title", "shape", "area", "width", "height", "points", "closed", "outset", "radius", "trim", "fill", "stroke",
        "adjust", "media", "in", "origin", "out", "speed", "loop", "timeRemap", "filter", "conform", "border", "shadow"
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
        let writtenStoryline = try object.member("storyline").elements()
        let storyline = try writtenStoryline.map(storyline)
        let written = try object.member("clips").elements()
        let clips = try written.map(clip)
        try checkParents(of: clips, places: written.map(\.place), storyline: storyline)
        try checkTrackedMedia(
            of: clips,
            places: written.map(\.place),
            storyline: storyline,
            storylinePlaces: writtenStoryline.map(\.place)
        )
        // Evaluation follows each track matte chain to its end and draws its clips, so the checks of resolve hold here.
        try TrackMatteFinder().check(
            zip(storyline, writtenStoryline).map { entry, value in TrackMatteLink(entry: entry, place: value.place) }
                + zip(clips, written).map { clip, value in
                    TrackMatteLink(clip: clip, place: value.place, kind: kind(of: clip))
                }
        )

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

        for index in clips.indices {
            guard let cycle = parents.cycle(from: index) else { continue }

            throw ResolveError.parentCycle(
                place: places[cycle[0]].appending(key: "parent"),
                kind: kind(of: clips[cycle[0]]),
                ids: cycle.map { clips[$0].id ?? clips[$0].place }
            )
        }
    }

    // Evaluation moves a tracked clip by its track's motion on the clock of the media it follows, its own or its
    // parent's as the clip decides, so a track that pins other media stops here, where only the reader can see it.
    private func checkTrackedMedia(
        of clips: [ResolvedClip],
        places: [Place],
        storyline: [ResolvedStorylineClip],
        storylinePlaces: [Place]
    ) throws {
        for (entry, place) in zip(storyline, storylinePlaces) {
            guard let track = entry.track else { continue }
            guard case let .pinned(media) = entry.media, track.media == media else {
                throw trackedMediaMismatch(at: place, followsParent: false)
            }
        }

        for (clip, place) in zip(clips, places) {
            guard let track = clip.track else { continue }

            if let media = clip.ownTrackedMedia {
                guard track.media == media else { throw trackedMediaMismatch(at: place, followsParent: false) }
            } else {
                guard track.media == pinnedMedia(of: clip.parent, clips: clips, storyline: storyline) else {
                    throw trackedMediaMismatch(at: place, followsParent: true)
                }
            }
        }
    }

    private func trackedMediaMismatch(
        at place: Place,
        followsParent: Bool
    ) -> ModelError {
        .invalidValue(
            place: place.appending(key: "track").appending(key: "media"),
            kind: "track",
            reason: followsParent
                ? "the clip follows its parent's media, so its track pins the media its parent shows"
                : "the clip follows its own media, so its track pins the media the clip shows"
        )
    }

    // The pinned media of the storyline entry or clip with the id, nil for none or for one without pinned media.
    private func pinnedMedia(
        of id: String?,
        clips: [ResolvedClip],
        storyline: [ResolvedStorylineClip]
    ) -> PinnedMedia? {
        guard let id else { return nil }

        let content: ResolvedMediaContent? = if let entry = storyline.first(where: { $0.id == id }) {
            entry.media
        } else if case let .media(media) = clips.first(where: { $0.id == id })?.content {
            media.media
        } else {
            nil
        }
        guard case let .pinned(media) = content else { return nil }

        return media
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
            duration: try duration(format.member("duration")),
            background: try values.color(format.member("background")),
            conform: try conform(format.member("conform"))
        )
    }

    // The sequence end, above 0: a nested sequence holds its media time inside `[0, duration)`.
    private func duration(_ value: PlacedJSONValue) throws -> Double {
        let duration = try value.number()
        guard duration > 0 else {
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "a sequence's duration is above 0, found \(value.value.written)"
            )
        }

        return duration
    }

    private func storyline(_ value: PlacedJSONValue) throws -> ResolvedStorylineClip {
        let entry = try value.object(kind: "storyline clip", keys: [
            "place", "id", "media", "solid", "in", "out", "speed", "timeRemap", "start", "end", "size", "position",
            "anchor", "crop", "mask", "trackMatte", "track", "opacity", "scale", "rotation", "blend", "filter",
            "radius", "border", "shadow", "transition"
        ])

        return ResolvedStorylineClip(
            place: try entry.member("place").string(),
            id: try entry.member("id").optional { try $0.string() },
            media: try entry.member("media").optional(media),
            solid: try entry.member("solid").optional(values.color),
            in: try entry.member("in").number(),
            out: try entry.member("out").number(),
            speed: try entry.member("speed").number(),
            timeRemap: try entry.member("timeRemap").optional(values.numbers),
            start: try entry.member("start").number(),
            end: try entry.member("end").number(),
            crop: try values.crops(entry.member("crop")),
            mask: try values.masks(entry.member("mask")),
            trackMatte: try entry.member("trackMatte").optional(trackMatte),
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

    // What a clip draws decides the keys it holds: its content's, then scale and rotation for anything but an
    // adjustment. A shape without `size` is placed by its geometry, and its `position` and `anchor` are its own.
    private func clip(_ value: PlacedJSONValue) throws -> ResolvedClip {
        let written = try value.object(kind: "clip", keys: Self.clipKeys + Self.contentKeys)
        let contentKeys = try self.contentKeys(of: written)
        let isTransformed = !written.contains("adjust")
        let clip = try value.object(
            kind: "clip",
            keys: Self.clipKeys.filter { key in
                isTransformed || key != "scale" && key != "rotation"
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
            box: box,
            crop: try clip.member("crop").optional(values.crops),
            mask: try values.masks(clip.member("mask")),
            trackMatte: try clip.member("trackMatte").optional(trackMatte),
            track: try clip.member("track").optional(track),
            opacity: try values.numbers(clip.member("opacity")),
            scale: isTransformed ? try values.numbers(clip.member("scale")) : nil,
            rotation: isTransformed ? try values.numbers(clip.member("rotation")) : nil,
            blend: try clip.member("blend").string(),
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
            let timing = clip.contains("origin") ? ["in", "origin", "out", "speed", "loop", "timeRemap"] : []

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

        let timing = clip.contains("origin") ? try self.timing(of: clip) : nil

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
                outset: try values.timed(clip.member("outset"), as: LookStructureTable.length)
            )
        } else {
            .area(
                try values.keyframes(clip.member("area"), read: values.rectangle),
                outset: try values.timed(clip.member("outset"), as: LookStructureTable.length),
                placement: try placement(of: clip)
            )
        }

        return ResolvedShape(
            kind: kind,
            geometry: geometry,
            radius: try values.timed(clip.member("radius"), as: LookStructureTable.length),
            trim: try values.keyframes(clip.member("trim")) { value in
                let ends = try value.numbers()
                guard ends.count == 2 else { throw value.wrongType("[a, b]") }

                return Trim(start: ends[0], end: ends[1])
            },
            fill: try values.timed(clip.member("fill"), as: LookStructureTable.fill),
            stroke: try values.timed(clip.member("stroke"), as: LookStructureTable.stroke, kind: "stroke"),
            shadow: try values.timed(clip.member("shadow"), as: LookStructureTable.shadow, kind: "shadow")
        )
    }

    private func placement(of clip: PlacedJSONObject) throws -> GeometryPlacement {
        GeometryPlacement(
            position: try clip.member("position").optional { value in try values.keyframes(value, read: values.point) },
            anchor: try clip.member("anchor").optional(values.point)
        )
    }

    // A clip with `timeRemap` has no `in`, `out` or `loop`.
    private func timing(of clip: PlacedJSONObject) throws -> MediaTiming {
        let origin = try clip.member("origin").number()
        if let timeRemap = try clip.member("timeRemap").optional(values.numbers) {
            return .remapped(origin: origin, timeRemap: timeRemap)
        }

        return .played(PlayedRange(
            map: TimeMap(origin: origin, in: try clip.member("in").number(), speed: try clip.member("speed").number()),
            out: try clip.member("out").number(),
            loop: try clip.member("loop").bool()
        ))
    }

    private func sound(_ value: PlacedJSONValue) throws -> ResolvedSound {
        let sound = try value.object(kind: "audio", keys: [
            "place", "media", "nested", "in", "origin", "out", "speed", "loop", "start", "end", "audible", "volume",
            "pan", "fadeIn", "fadeOut", "incoming", "outgoing"
        ])
        let range = { (key: String) in try sound.member(key).optional(values.range) }

        return ResolvedSound(
            place: try sound.member("place").string(),
            media: try sound.member("media").optional(values.media),
            nested: try sound.member("nested").elements().map(self.sound),
            played: PlayedRange(
                map: TimeMap(
                    origin: try sound.member("origin").number(),
                    in: try sound.member("in").number(),
                    speed: try sound.member("speed").number()
                ),
                out: try sound.member("out").number(),
                loop: try sound.member("loop").bool()
            ),
            start: try sound.member("start").number(),
            end: try sound.member("end").number(),
            audible: try values.range(sound.member("audible")),
            volume: try values.numbers(sound.member("volume")),
            pan: try values.numbers(sound.member("pan")),
            fadeIn: try range("fadeIn"),
            fadeOut: try range("fadeOut"),
            incoming: try sound.member("incoming").optional(crossfade),
            outgoing: try sound.member("outgoing").optional(crossfade)
        )
    }

    private func crossfade(_ value: PlacedJSONValue) throws -> Crossfade {
        let crossfade = try value.object(kind: "crossfade", keys: ["start", "end", "audio"])

        return Crossfade(
            range: TimeRange(start: try crossfade.member("start").number(), end: try crossfade.member("end").number()),
            curve: try curve(crossfade.member("audio"))
        )
    }

    private func curve(_ value: PlacedJSONValue) throws -> CrossfadeCurve {
        try value.name(among: CrossfadeCurve.allCases.map(\.rawValue), CrossfadeCurve.init)
    }

    // Pinned media, or a nested sequence, which names its `kind`.
    private func media(_ value: PlacedJSONValue) throws -> ResolvedMediaContent {
        guard value.value.objectValue?.contains("kind") == true else { return .pinned(try values.media(value)) }

        return .nested(try document(value))
    }

    private func trackMatte(_ value: PlacedJSONValue) throws -> TrackMatte {
        let matte = try value.object(kind: "track matte", keys: ["clip", "mode", "invert"])
        let modes = TrackMatteMode.allCases.map(\.rawValue)

        return TrackMatte(
            clip: try matte.member("clip").string(),
            mode: try matte.member("mode").name(among: modes, TrackMatteMode.init(rawValue:)),
            isInverted: try matte.member("invert").bool()
        )
    }

    private func track(_ value: PlacedJSONValue) throws -> ResolvedTrack {
        let track = try value.object(kind: "track", keys: ["media", "time", "target", "frames"])
        let target = try values.quad(track.member("target"))

        return ResolvedTrack(
            media: try values.media(track.member("media")),
            track: Track(
                target: target,
                mediaTime: try track.member("time").number(),
                samples: try track.member("frames").elements().map { element in
                    let frame = try element.object(keys: ["time", "quad", "motion"])

                    return TrackSample(
                        time: try frame.member("time").number(),
                        quad: try values.quad(frame.member("quad")),
                        motion: TrackMotion(transform: try motion(frame.member("motion")), origin: target.centroid)
                    )
                }
            )
        )
    }

    // A similarity, `[a, b, -b, a, tx, ty]` with a scale above 0, since evaluation takes its scale and rotation apart
    // and brings values back through its inverse.
    private func motion(_ value: PlacedJSONValue) throws -> AffineTransform {
        let motion = AffineTransform(matrix: try value.numbers(count: 6))
        guard motion.d == motion.a, motion.c == -motion.b, motion.a != 0 || motion.b != 0 else {
            throw ModelError.invalidValue(
                place: value.place,
                kind: value.kind,
                reason: "a track's motion is a move, one scale above 0 and one rotation, written [a, b, -b, a, tx, ty], found \(value.value.written)"
            )
        }

        return motion
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
