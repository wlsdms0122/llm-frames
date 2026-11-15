//
//  TimePlanner.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Plans the time of a sequence that passed the key tables: storyline clips end to end, their transitions and ranges,
// and the window of every other clip, with every stop of time on the way.
struct TimePlanner: Sendable {
    // MARK: - Property
    private static let frameRates: [Double] = [24, 25, 30, 50, 60]
    private static let defaultFrameRate: Double = 30

    private let mediaFacts: any MediaFactProvider
    private let presets: any PresetProvider
    private let reader = SequenceReader()
    private let merger = ThemeMerger()

    // MARK: - Initializer
    init(
        mediaFacts: any MediaFactProvider,
        presets: any PresetProvider
    ) {
        self.mediaFacts = mediaFacts
        self.presets = presets
    }

    // MARK: - Public
    // `theme` is the theme in effect where the document is written: the base theme with a --theme file over it.
    func plan(
        document: JSONValue,
        theme: JSONValue = BaseTheme.value
    ) throws -> TimePlan {
        try plan(reader.sequence(from: document), theme: theme)
    }

    func plan(
        _ sequence: SequenceDocument,
        theme: JSONValue
    ) throws -> TimePlan {
        guard !sequence.storyline.isEmpty else {
            throw ResolveError.emptyStoryline(place: sequence.place.appending(key: "storyline"))
        }

        let merged = try self.theme(of: sequence, over: theme)
        let defaults = ThemeDefaults(theme: merged)
        let sources = try sequence.storyline.map { clip in try source(of: clip, theme: merged) }
        let storyline = try layOut(sequence.storyline, sources: sources, defaults: defaults)
        let duration = storyline[storyline.count - 1].edit.end

        let connected = try sequence.storyline.enumerated().flatMap { index, clip in
            try clip.connected.map { connected in
                try plan(connected, owner: index, storyline: storyline, duration: duration, defaults: defaults, theme: merged)
            }
        }
        let clips = try sequence.clips.map { clip in
            try plan(clip, owner: nil, storyline: storyline, duration: duration, defaults: defaults, theme: merged)
        }

        return TimePlan(
            duration: duration,
            fps: sequence.format.fps ?? frameRate(of: sources),
            storyline: storyline,
            clips: connected + clips
        )
    }

    // MARK: - Private
    private func theme(
        of sequence: SequenceDocument,
        over theme: JSONValue
    ) throws -> JSONValue {
        switch sequence.theme {
        case nil:
            return theme

        case let .object(layer):
            return try merger.merge([layer], over: theme)

        case let .named(name):
            throw ResolveError.unreadReference(place: sequence.place.appending(key: "theme"), kind: "sequence", reference: name)
        }
    }

    private func source(
        of clip: StorylineClip,
        theme: JSONValue
    ) throws -> StorylineSource {
        guard let clipMedia = clip.media else {
            let duration = try stillDuration(of: clip, kind: .solid)
            return StorylineSource(kind: .solid, media: nil, clipRange: TimeRange(start: 0, end: duration), speed: 1)
        }

        let media = try resolve(clipMedia.source, place: clip.place.appending(key: "media"), kind: "storyline clip", theme: theme)
        let kind = ClipKind.media(media.kind)
        guard media.kind != .image else {
            let duration = try stillDuration(of: clip, kind: kind)
            return StorylineSource(kind: kind, media: media, clipRange: TimeRange(start: 0, end: duration), speed: 1)
        }

        return StorylineSource(
            kind: kind,
            media: media,
            clipRange: try clipRange(of: clipMedia, media: media, place: clip.place, kind: kind),
            speed: try speed(of: clipMedia, place: clip.place, kind: kind)
        )
    }

    private func resolve(
        _ source: MediaSource,
        place: Place,
        kind: String,
        theme: JSONValue
    ) throws -> ResolvedMedia {
        switch source {
        case let .file(file):
            guard let probed = mediaFacts.probedMedia(of: file) else {
                throw ResolveError.unprobedMedia(place: place, kind: kind, reference: file)
            }
            // A document named by its path is read with packs and templates, before time is planned.
            guard probed.kind != .sequence else {
                throw ResolveError.unreadReference(place: place, kind: kind, reference: file)
            }

            return ResolvedMedia(
                kind: probed.kind,
                file: file,
                duration: probed.duration,
                fps: probed.fps,
                frames: frames(of: probed)
            )

        case let .imageSequence(directory, fps):
            guard let count = mediaFacts.frameCount(ofImageSequence: directory) else {
                throw ResolveError.unprobedMedia(place: place, kind: kind, reference: directory)
            }

            // Its media seconds are frame index / fps, so its last frame starts one frame before its end.
            let duration = Double(count) / fps
            return ResolvedMedia(
                kind: .video,
                file: directory,
                duration: duration,
                fps: fps,
                frames: 0...max(duration - 1 / fps, 0)
            )

        case let .compound(document):
            let nested = try plan(document, theme: theme)
            // A compound clip is evaluated at whatever time is asked, clamped into [0, duration).
            return ResolvedMedia(
                kind: .sequence,
                file: nil,
                duration: nested.duration,
                frames: 0...nested.duration.nextDown,
                nested: nested
            )

        case .document:
            return ResolvedMedia(kind: .image, file: nil, duration: 0)

        case let .template(name), let .parameter(name):
            throw ResolveError.unreadReference(place: place, kind: kind, reference: name)
        }
    }

    private func frames(of probed: ProbedMedia) -> ClosedRange<Double>? {
        guard probed.kind == .video else { return nil }
        guard let first = probed.frames.first, let last = probed.frames.last else { return 0...probed.duration }

        return first...last
    }

    private func stillDuration(
        of clip: StorylineClip,
        kind: ClipKind
    ) throws -> Double {
        guard let duration = clip.duration else {
            throw ResolveError.missingKey(place: clip.place, kind: kind.label, key: "duration")
        }
        guard duration > 0 else {
            throw ResolveError.nonPositiveDuration(place: clip.place.appending(key: "duration"), kind: kind.label, duration: duration)
        }

        return duration
    }

    // `in` defaults to the start of the media and `out` to its end, and each is cut to the media where it lies past it.
    private func clipRange(
        of clipMedia: ClipMedia,
        media: ResolvedMedia,
        place: Place,
        kind: ClipKind
    ) throws -> TimeRange {
        let start = max(clipMedia.in ?? 0, 0)
        let end = min(clipMedia.out ?? media.duration, media.duration)
        guard start < end else {
            throw ResolveError.emptyClipRange(place: place, kind: kind.label, in: start, out: end)
        }

        return TimeRange(start: start, end: end)
    }

    private func speed(
        of clipMedia: ClipMedia,
        place: Place,
        kind: ClipKind
    ) throws -> Double {
        let speed = clipMedia.speed ?? 1
        guard speed > 0 else {
            throw ResolveError.nonPositiveSpeed(place: place.appending(key: "speed"), kind: kind.label, speed: speed)
        }

        return speed
    }

    private func layOut(
        _ clips: [StorylineClip],
        sources: [StorylineSource],
        defaults: ThemeDefaults
    ) throws -> [StorylinePlan] {
        // Each clip starts where the previous one ends, so the last entry is where the sequence ends.
        let editPoints = sources.reduce(into: [0.0]) { points, source in
            points.append(points[points.count - 1] + source.duration)
        }
        let transitions = try clips.indices.map { index in
            try transition(
                of: clips[index],
                index: index,
                sources: sources,
                editPoint: editPoints[index],
                defaults: defaults
            )
        }

        return try clips.indices.map { index in
            let edit = TimeRange(start: editPoints[index], end: editPoints[index + 1])
            let outgoing = transitions.indices.contains(index + 1) ? transitions[index + 1] : nil
            let drawn = TimeRange(start: transitions[index]?.range.start ?? edit.start, end: outgoing?.range.end ?? edit.end)
            let map = TimeMap(origin: edit.start, in: sources[index].clipRange.start, speed: sources[index].speed)
            let keyframes = clips[index].keyframes.map { keyframe in keyframe.moved(to: map.sequenceTime(ofClipTime: keyframe.at)) }
            try checkKeyframes(keyframes, visible: drawn, place: clips[index].place, kind: sources[index].kind)

            return StorylinePlan(
                place: clips[index].place,
                id: clips[index].id,
                source: sources[index],
                edit: edit,
                drawn: drawn,
                transition: transitions[index],
                keyframes: keyframes
            )
        }
    }

    private func transition(
        of clip: StorylineClip,
        index: Int,
        sources: [StorylineSource],
        editPoint: Double,
        defaults: ThemeDefaults
    ) throws -> TransitionPlan? {
        let kind = sources[index].kind
        guard index > 0 else {
            guard clip.transition == nil else {
                throw ResolveError.transitionOnFirstClip(place: clip.place.appending(key: "transition"), kind: kind.label)
            }

            return nil
        }

        let lengths = [sources[index - 1].duration, sources[index].duration]
        switch clip.transition ?? defaults.transition {
        case .cut:
            return nil

        case let .preset(name):
            let definition = try transitionPreset(named: name, place: clip.place, kind: kind)
            return transitionPlan(name, seconds: definition.seconds, definition: definition, editPoint: editPoint, lengths: lengths)

        case let .timed(name, seconds):
            guard seconds > 0 else {
                throw ResolveError.nonPositiveTransition(
                    place: clip.place.appending(key: "transition"),
                    kind: kind.label,
                    seconds: seconds
                )
            }

            let definition = try transitionPreset(named: name, place: clip.place, kind: kind)
            return transitionPlan(name, seconds: seconds, definition: definition, editPoint: editPoint, lengths: lengths)
        }
    }

    // A transition is cut to the shorter of the two clips it joins, and is centred on their edit point.
    private func transitionPlan(
        _ name: String,
        seconds: Double,
        definition: TransitionPreset,
        editPoint: Double,
        lengths: [Double]
    ) -> TransitionPlan {
        let length = ([seconds] + lengths).min() ?? seconds
        return TransitionPlan(
            preset: name,
            seconds: length,
            range: TimeRange(start: editPoint - length / 2, end: editPoint + length / 2),
            definition: definition
        )
    }

    private func transitionPreset(
        named name: String,
        place: Place,
        kind: ClipKind
    ) throws -> TransitionPreset {
        guard let preset = try presets.transition(named: name) else {
            throw ResolveError.unknownPreset(place: place, kind: kind.label, presetKind: "transition", name: name)
        }

        return preset
    }

    private func plan(
        _ clip: Clip,
        owner: Int?,
        storyline: [StorylinePlan],
        duration: Double,
        defaults: ThemeDefaults,
        theme: JSONValue
    ) throws -> ClipPlan {
        let clipMedia = media(of: clip)
        let media = try clipMedia.map { clipMedia in
            try resolve(clipMedia.source, place: clip.place.appending(key: "media"), kind: "clip", theme: theme)
        }
        let kind = kind(of: clip, media: media)
        let isParented = try parented(clip, kind: kind)
        let ownerPlan = owner.map { storyline[$0] }
        let clock = ownerPlan?.map ?? .sequence

        let timed = try timedMedia(clipMedia, media: media, place: clip.place, kind: kind)
        let window = try self.window(
            of: clip,
            clock: clock,
            naturalLength: timed?.naturalLength,
            owner: ownerPlan,
            isParented: isParented,
            duration: duration,
            kind: kind
        )
        let visible = try self.visible(
            clip,
            window: window,
            owner: ownerPlan,
            isParented: isParented,
            duration: duration,
            kind: kind
        )
        let keyframes = clip.keyframes.map { keyframe in keyframe.moved(to: clock.sequenceTime(ofClipTime: keyframe.at)) }
        try checkKeyframes(keyframes, visible: visible, place: clip.place, kind: kind)

        return ClipPlan(
            place: clip.place,
            id: clip.id,
            kind: kind,
            storyline: owner,
            isParented: isParented,
            lane: try lane(of: clip, kind: kind),
            clock: clock,
            window: window,
            visible: visible,
            animation: try animation(of: clip, kind: kind, isParented: isParented, defaults: defaults),
            media: media,
            timing: timed.map { timed in
                MediaTiming(
                    media: timed.media,
                    map: TimeMap(origin: window.start, in: timed.map.in, speed: timed.map.speed),
                    out: timed.out,
                    loop: timed.loop
                )
            },
            keyframes: keyframes
        )
    }

    private func media(of clip: Clip) -> ClipMedia? {
        guard case let .media(clipMedia) = clip.content else { return nil }

        return clipMedia
    }

    private func kind(
        of clip: Clip,
        media: ResolvedMedia?
    ) -> ClipKind {
        switch clip.content {
        case .media:
            .media(media?.kind ?? .image)

        case .title:
            .title

        case let .shape(shape):
            .shape(shape)

        case .adjust:
            .adjust
        }
    }

    // Shapes and adjustments placed by an area are parented, and a title or media clip is when it says so.
    private func parented(
        _ clip: Clip,
        kind: ClipKind
    ) throws -> Bool {
        guard clip.clipPlace == .connected else {
            guard !clip.hasParent else { throw ResolveError.parentOnSequenceClip(place: clip.place, kind: kind.label) }

            return false
        }
        guard !clip.hasParent || !clip.hasPlacement else {
            throw ResolveError.parentWithPlacement(place: clip.place, kind: kind.label)
        }

        switch clip.content {
        case .shape, .adjust:
            return clip.hasArea

        case .title, .media:
            return clip.hasParent
        }
    }

    // A timed media clip's edit points, with its window's start left at 0 until the window is known.
    private func timedMedia(
        _ clipMedia: ClipMedia?,
        media: ResolvedMedia?,
        place: Place,
        kind: ClipKind
    ) throws -> MediaTiming? {
        guard let clipMedia, let media, media.kind != .image else { return nil }

        let range = try clipRange(of: clipMedia, media: media, place: place, kind: kind)
        return MediaTiming(
            media: media,
            map: TimeMap(origin: 0, in: range.start, speed: try speed(of: clipMedia, place: place, kind: kind)),
            out: range.end,
            loop: clipMedia.loop
        )
    }

    private func window(
        of clip: Clip,
        clock: TimeMap,
        naturalLength: Double?,
        owner: StorylinePlan?,
        isParented: Bool,
        duration: Double,
        kind: ClipKind
    ) throws -> TimeRange {
        switch clip.at {
        case let .range(start, end):
            guard start < end else {
                throw ResolveError.emptyWindow(place: clip.place.appending(key: "at"), kind: kind.label, start: start, end: end)
            }

            return TimeRange(start: clock.sequenceTime(ofClipTime: start), end: clock.sequenceTime(ofClipTime: end))

        case let .start(start):
            let sequenceStart = clock.sequenceTime(ofClipTime: start)
            return TimeRange(start: sequenceStart, end: sequenceStart + (naturalLength ?? 0))

        case nil:
            guard let owner else { return TimeRange(start: 0, end: duration) }

            return isParented ? owner.drawn : owner.edit
        }
    }

    private func visible(
        _ clip: Clip,
        window: TimeRange,
        owner: StorylinePlan?,
        isParented: Bool,
        duration: Double,
        kind: ClipKind
    ) throws -> TimeRange {
        let sequence = TimeRange(start: 0, end: duration)
        let isAudio = kind == .media(.audio)

        guard let owner else {
            guard window.start < duration else {
                throw ResolveError.startsAtOrAfterEnd(place: clip.place, kind: kind.label, start: window.start, end: duration)
            }
            guard let visible = window.intersection(sequence) else {
                throw isAudio
                    ? ResolveError.neverPlays(place: clip.place, kind: kind.label, window: window)
                    : ResolveError.neverVisible(place: clip.place, kind: kind.label, window: window, range: sequence)
            }

            return visible
        }

        guard !isAudio else {
            guard owner.drawn.contains(window.start), let visible = window.intersection(sequence) else {
                throw ResolveError.audioStartOutsideDrawnRange(
                    place: clip.place,
                    kind: kind.label,
                    start: window.start,
                    drawn: owner.drawn
                )
            }

            return visible
        }

        // A parented clip is composited with its picture, and an unparented one plays over whatever is below it.
        let range = isParented ? owner.drawn : sequence
        guard let visible = window.intersection(range) else {
            throw ResolveError.neverVisible(place: clip.place, kind: kind.label, window: window, range: range)
        }

        return visible
    }

    private func lane(
        of clip: Clip,
        kind: ClipKind
    ) throws -> Int? {
        guard kind != .media(.audio) else { return nil }

        let lane = clip.lane ?? 1
        guard lane != 0 else { throw ResolveError.zeroLane(place: clip.place.appending(key: "lane"), kind: kind.label) }

        return lane
    }

    // A parented clip without `at` comes and goes with its picture, so it takes no entrance and no exit.
    private func animation(
        of clip: Clip,
        kind: ClipKind,
        isParented: Bool,
        defaults: ThemeDefaults
    ) throws -> AnimationPlan {
        guard kind != .media(.audio) else { return .none }

        let plan = try animationPlan(clip.animation ?? defaults.animation(for: clip.content), place: clip.place, kind: kind)
        guard isParented, clip.at == nil else { return plan }

        return plan.withoutEntranceAndExit()
    }

    private func animationPlan(
        _ choice: AnimationChoice,
        place: Place,
        kind: ClipKind
    ) throws -> AnimationPlan {
        switch choice {
        case .none:
            return .none

        case let .preset(name):
            let preset = try animationPreset(named: name, place: place, kind: kind)
            return AnimationPlan(
                entrance: preset?.entrance.map { PresetSpan(preset: name, span: $0) },
                loop: preset?.loop.map { PresetSpan(preset: name, span: $0) },
                exit: preset?.exit.map { PresetSpan(preset: name, span: $0) }
            )

        case let .split(entrance, exit):
            let entrancePreset = try animationPreset(named: entrance, place: place, kind: kind)
            let exitPreset = try animationPreset(named: exit, place: place, kind: kind)
            return AnimationPlan(
                entrance: entrancePreset?.entrance.map { PresetSpan(preset: entrance, span: $0) },
                loop: nil,
                exit: exitPreset?.exit.map { PresetSpan(preset: exit, span: $0) }
            )
        }
    }

    // `none` names no preset, so it is nil without a lookup.
    private func animationPreset(
        named name: String,
        place: Place,
        kind: ClipKind
    ) throws -> AnimationPreset? {
        guard name != "none" else { return nil }
        guard let preset = try presets.animation(named: name) else {
            throw ResolveError.unknownPreset(place: place, kind: kind.label, presetKind: "animation", name: name)
        }

        return preset
    }

    // A property whose keyframes all lie before or all after the range its clip shows in would only ever show one value.
    private func checkKeyframes(
        _ keyframes: [KeyframeInstant],
        visible: TimeRange,
        place: Place,
        kind: ClipKind
    ) throws {
        let properties = keyframes.flatMap(\.properties).reduce(into: [String]()) { properties, property in
            guard !properties.contains(property) else { return }

            properties.append(property)
        }

        for property in properties {
            let instants = keyframes.filter { $0.properties.contains(property) }.map(\.at)
            let isBefore = instants.allSatisfy { $0 < visible.start }
            let isAfter = instants.allSatisfy { $0 >= visible.end }
            guard !isBefore, !isAfter else {
                throw ResolveError.keyframesOutsideVisibleRange(
                    place: place.appending(key: "keyframes"),
                    kind: kind.label,
                    property: property,
                    visible: visible
                )
            }
        }
    }

    // The nominal rate of the first video on the storyline, to the nearest common rate.
    private func frameRate(of sources: [StorylineSource]) -> Double {
        guard let rate = sources.first(where: { $0.media?.kind == .video })?.media?.fps else { return Self.defaultFrameRate }

        return Self.frameRates.min { abs($0 - rate) < abs($1 - rate) } ?? Self.defaultFrameRate
    }
}
