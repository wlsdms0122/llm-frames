//
//  TrackPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what `track` follows. The target is found at the clip's instant before padding, and the tracker follows it in
// the storyline clip's media over every frame that clip draws, handles included, and the frames between them and the
// instant. A storyline clip that loses its target inside its edit range stops, and a connected clip is visible only
// on the frames followed.
struct TrackPlanner: Sendable {
    // MARK: - Property
    // Sequence times are sums and quotients of media times, so a frame boundary may miss an edit point by rounding.
    private static let tolerance = 1e-9

    private let tracker: any TrackerProvider
    private let finder: AreaFinder

    // MARK: - Initializer
    init(
        tracker: any TrackerProvider,
        ocr: any OCRProvider
    ) {
        self.tracker = tracker
        self.finder = AreaFinder(ocr: ocr)
    }

    // MARK: - Public
    // `crops` and `storylineMasks` are what was found for each storyline clip's crop and mask, and `areas` and `masks`
    // for each other clip's area and mask, in the time plan's order, which `true` follows.
    func plan(
        _ time: TimePlan,
        crops: [PropertyValue<FoundArea>?],
        storylineMasks: [PropertyValue<[ResolvedMask]>?],
        areas: [PropertyValue<FoundArea>?],
        masks: [PropertyValue<[ResolvedMask]>?]
    ) throws -> TrackPlan {
        let storyline = try time.storyline.indices.map { index in
            try track(
                time.storyline[index],
                written: time.sequence.storyline[index],
                crop: crops[index],
                mask: storylineMasks[index]
            )
        }

        let written = time.sequence.storyline.flatMap(\.connected) + time.sequence.clips
        let clips = try time.clips.indices.map { index in
            try track(
                time.clips[index],
                written: written[index],
                area: areas[index],
                mask: masks[index],
                storyline: time.storyline
            )
        }

        return TrackPlan(time: time.replacingClips(clips.map(\.plan)), storyline: storyline, clips: clips.map(\.track))
    }

    // MARK: - Private
    private func track(
        _ plan: StorylinePlan,
        written: StorylineClip,
        crop: PropertyValue<FoundArea>?,
        mask: PropertyValue<[ResolvedMask]>?
    ) throws -> Track? {
        guard let target = written.track else { return nil }

        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.source.kind)
        guard let picture = picture(of: plan) else { throw ResolveError.trackWithoutVideo(place: place, kind: kind) }

        let start = try self.target(
            target,
            candidates: [
                ("crop", isArea(written.crop) ? crop : nil),
                ("mask", mask.map { self.area(of: $0, on: plan, instant: plan.instant) })
            ],
            in: picture.picture,
            atMediaTime: plan.mediaTime(atSequenceTime: plan.instant),
            place: place,
            kind: kind
        )
        let followed = try follow(start, on: plan, file: picture.file)
        let isEditFollowed = followed.range.start <= plan.edit.start + Self.tolerance
            && followed.range.end >= plan.edit.end - Self.tolerance
        guard isEditFollowed else {
            throw ResolveError.trackLost(
                place: place,
                kind: kind,
                followed: shown(followed.range, in: plan),
                edit: plan.edit
            )
        }

        return followed.track
    }

    // `true` belongs to a shape or an adjustment with an area or a mask in its parent's space, and a title or media
    // clip names what it follows. A parented clip follows its parent's media, which must be a storyline clip's video or
    // image sequence.
    private func track(
        _ plan: ClipPlan,
        written: Clip,
        area: PropertyValue<FoundArea>?,
        mask: PropertyValue<[ResolvedMask]>?,
        storyline: [StorylinePlan]
    ) throws -> (plan: ClipPlan, track: Track?) {
        guard let target = written.track else { return (plan, nil) }

        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.kind)
        if target == .own, isNaming(plan.kind) {
            throw ResolveError.trackOwnOnNamingClip(place: place, kind: kind)
        }
        if target == .own, area == nil, mask == nil {
            throw ResolveError.trackOwnWithoutArea(place: place, kind: kind)
        }
        if case let .clip(_, id) = plan.parent {
            throw ResolveError.trackInClipParent(place: place, kind: kind, id: id)
        }
        guard
            case let .storyline(index, _) = plan.parent,
            let picture = picture(of: storyline[index])
        else {
            throw ResolveError.trackWithoutVideo(place: place, kind: kind)
        }

        let parent = storyline[index]
        // Only a mask in the parent's space lies in the media followed; a box shape's is in its own box.
        let ownMask = plan.space == .parent ? mask.map { self.area(of: $0, on: parent, instant: plan.instant) } : nil
        let start = try self.target(
            target,
            candidates: [
                ("area", area),
                ("mask", ownMask)
            ],
            in: picture.picture,
            atMediaTime: parent.mediaTime(atSequenceTime: plan.instant),
            place: place,
            kind: kind
        )
        let followed = try follow(start, on: parent, file: picture.file)
        guard let visible = plan.visible.intersection(followed.range) else {
            throw ResolveError.neverFollowed(place: written.place, kind: kind, visible: plan.visible)
        }

        return (plan.narrowed(to: visible), followed.track)
    }

    // What `true` follows (FRAMES-12): the one of the clip's area, mask and crop it has, each where it starts. A clip
    // with more than one stops, since it must name its target.
    private func own(
        _ candidates: [(key: String, value: PropertyValue<FoundArea>?)],
        place: Place,
        kind: PlaceKind
    ) throws -> PropertyValue<FoundArea>? {
        let present = candidates.filter { $0.value != nil }
        guard present.count <= 1 else {
            throw ResolveError.trackOwnAmbiguous(place: place, kind: kind, keys: present.map(\.key))
        }

        return present.first?.value
    }

    // The bounding box of every mask's geometry, without feather, at each value's time, as the area `true` follows: a
    // keyframe's at its own time, and a static mask at the clip's instant.
    private func area(
        of mask: PropertyValue<[ResolvedMask]>,
        on storyline: StorylinePlan,
        instant: Double
    ) -> PropertyValue<FoundArea> {
        let found = { (masks: [ResolvedMask], time: Double) in
            let bounds = masks.bounds ?? Rectangle(x: 0, y: 0, width: 0, height: 0)
            return FoundArea(
                rectangle: bounds,
                target: bounds,
                mediaTime: storyline.mediaTime(atSequenceTime: time),
                lines: []
            )
        }

        switch mask {
        case let .value(masks):
            return .value(found(masks, instant))

        case let .keyframes(keyframes):
            return .keyframes(keyframes.map { keyframe in
                TimedValue(
                    index: keyframe.index,
                    at: keyframe.at,
                    value: found(keyframe.value, keyframe.at),
                    ease: keyframe.ease
                )
            })
        }
    }

    // The target before padding: for `true` the one of the clip's own candidates it has, where it starts, else the
    // area it names, found at the instant. A named target does not look at the candidates.
    private func target(
        _ target: TrackTarget,
        candidates: [(key: String, value: PropertyValue<FoundArea>?)],
        in picture: Picture,
        atMediaTime time: Double,
        place: Place,
        kind: PlaceKind
    ) throws -> FoundArea {
        switch target {
        case .own:
            let own = try own(candidates, place: place, kind: kind)
            guard let found = own?.firstValue else { throw ResolveError.trackOwnWithoutArea(place: place, kind: kind) }

            return found

        case let .area(form):
            return try finder.area(form, in: picture, atMediaTime: time, place: place, kind: kind.label)
        }
    }

    // Follows the target over the frames the storyline clip draws and those between them and the target's frame. The
    // range comes back in sequence time, open on a side where nothing needed was lost.
    private func follow(
        _ target: FoundArea,
        on plan: StorylinePlan,
        file: MediaFile
    ) throws -> (track: Track, range: TimeRange) {
        let drawnStart = plan.mediaTime(atSequenceTime: plan.drawn.start)
        let drawnEnd = plan.mediaTime(atSequenceTime: plan.drawn.end)
        let firstNeeded = file.frameTime(at: min(drawnStart, target.mediaTime)) ?? drawnStart
        let lastNeeded = max(drawnEnd, target.mediaTime)
        let frames = try tracker.track(
            target.target,
            in: file,
            atMediaTime: target.mediaTime,
            over: firstNeeded...lastNeeded
        )
        let track = Track(target: target.target, mediaTime: target.mediaTime, frames: frames)
        guard let first = frames.first, let last = frames.last else {
            let instant = plan.map.sequenceTime(ofClipTime: target.mediaTime)
            return (track, TimeRange(start: instant, end: instant))
        }

        let next = file.frameTime(after: last.time)
        let start = first.time <= firstNeeded ? -Double.infinity : plan.map.sequenceTime(ofClipTime: first.time)
        let end = next.map { $0 > lastNeeded ? Double.infinity : plan.map.sequenceTime(ofClipTime: $0) }
            ?? .infinity

        return (track, TimeRange(start: start, end: end))
    }

    // The video or image sequence a storyline clip plays, which a tracker can follow, and nil for a still, a solid or
    // a compound clip.
    private func picture(of plan: StorylinePlan) -> (picture: Picture, file: MediaFile)? {
        guard
            plan.source.kind == .media(.video),
            let media = plan.source.media,
            case let .file(file) = media.source,
            let size = file.size
        else {
            return nil
        }

        return (Picture(name: media.reference ?? file.path, source: .mediaFile(file), size: size), file)
    }

    // A crop `true` follows is an area where it starts, not a `{scale}`.
    private func isArea(_ crop: PropertyValue<CropForm>?) -> Bool {
        if case .area = crop?.firstValue { true } else { false }
    }

    private func isNaming(_ kind: ClipKind) -> Bool {
        switch kind {
        case .title, .media:
            true

        default:
            false
        }
    }

    // The followed range as a message shows it, within what the storyline clip draws.
    private func shown(
        _ range: TimeRange,
        in plan: StorylinePlan
    ) -> TimeRange {
        TimeRange(start: max(range.start, plan.drawn.start), end: min(range.end, plan.drawn.end))
    }
}
