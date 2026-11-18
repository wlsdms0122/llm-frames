//
//  TrackPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what `track` follows. The target is found at the clip's instant before padding, and the tracker follows it in
// the tracked media (FRAMES-12), a storyline or media clip's own video or image sequence and any other clip's parent's,
// over every frame the clip can show and the frames between them and the instant: a storyline clip's handles included,
// and through the clock of the tracked media's clip. A storyline clip that loses its target inside its edit range
// stops, and a connected or sequence clip is visible only on the frames followed.
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
    // `storylineCrops` and `storylineMasks` are what was found for each storyline clip's crop and mask, and `crops`,
    // `areas` and `masks` for each other clip's crop, area and mask, in the time plan's order, which `true` follows.
    func plan(
        _ time: TimePlan,
        storylineCrops: [PropertyValue<FoundArea>?],
        storylineMasks: [PropertyValue<[ResolvedMask]>?],
        crops: [PropertyValue<FoundArea>?],
        areas: [PropertyValue<FoundArea>?],
        masks: [PropertyValue<[ResolvedMask]>?]
    ) throws -> TrackPlan {
        let storyline = try time.storyline.indices.map { index in
            try track(
                time.storyline[index],
                written: time.sequence.storyline[index],
                crop: storylineCrops[index],
                mask: storylineMasks[index],
                fps: time.fps
            )
        }

        let written = time.sequence.storyline.flatMap(\.connected) + time.sequence.clips
        let clips = try time.clips.indices.map { index in
            try track(
                time.clips[index],
                written: written[index],
                crop: crops[index],
                area: areas[index],
                mask: masks[index],
                time: time,
                fps: time.fps
            )
        }

        return TrackPlan(time: time.replacingClips(clips.map(\.plan)), storyline: storyline, clips: clips.map(\.track))
    }

    // MARK: - Private
    private func track(
        _ plan: StorylinePlan,
        written: StorylineClip,
        crop: PropertyValue<FoundArea>?,
        mask: PropertyValue<[ResolvedMask]>?,
        fps: Double
    ) throws -> Track? {
        guard let target = written.track else { return nil }

        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.source.kind)
        guard let picture = picture(of: plan) else { throw ResolveError.trackWithoutVideo(place: place, kind: kind) }

        let start = try self.target(
            target,
            candidates: [
                ("crop", isArea(written.crop) ? crop : nil),
                ("mask", mask.map { self.area(of: $0, on: picture.clock, instant: plan.instant) })
            ],
            in: picture.picture,
            at: plan.instant,
            on: picture.clock,
            place: place,
            kind: kind
        )
        let followed = try follow(
            start.area,
            at: start.instant,
            on: picture.clock,
            drawn: plan.drawn,
            file: picture.file,
            fps: fps
        )
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

    // A media clip of video or image sequence follows its own media, where `true` follows its area crop or its mask,
    // and the frames needed are those its clock shows while it is visible. Any other clip follows its parent's media.
    private func track(
        _ plan: ClipPlan,
        written: Clip,
        crop: PropertyValue<FoundArea>?,
        area: PropertyValue<FoundArea>?,
        mask: PropertyValue<[ResolvedMask]>?,
        time: TimePlan,
        fps: Double
    ) throws -> (plan: ClipPlan, track: TrackedMedia?) {
        guard let target = written.track else { return (plan, nil) }

        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.kind)
        guard let picture = picture(of: plan) else {
            return try trackInParent(plan, written: written, target: target, area: area, mask: mask, time: time, fps: fps)
        }

        let start = try self.target(
            target,
            candidates: [
                ("crop", isArea(written.crop) ? crop : nil),
                ("mask", mask.map { self.area(of: $0, on: picture.clock, instant: plan.instant) })
            ],
            in: picture.picture,
            at: plan.instant,
            on: picture.clock,
            place: place,
            kind: kind
        )
        let followed = try follow(
            start.area,
            at: start.instant,
            on: picture.clock,
            drawn: plan.visible,
            file: picture.file,
            fps: fps
        )

        return (
            try narrowed(plan, to: followed.range, place: written.place),
            TrackedMedia(track: followed.track, file: picture.file, clock: picture.clock)
        )
    }

    // `true` belongs to a shape or an adjustment with an area or a mask in its parent's space, and a title, still or
    // compound clip names what it follows. The parent's media must be the video or image sequence of a storyline clip
    // or of a connected or sequence media clip. The frames needed under a storyline clip are those it draws, and under
    // any other parent those its clock shows while the clip is visible.
    private func trackInParent(
        _ plan: ClipPlan,
        written: Clip,
        target: TrackTarget,
        area: PropertyValue<FoundArea>?,
        mask: PropertyValue<[ResolvedMask]>?,
        time: TimePlan,
        fps: Double
    ) throws -> (plan: ClipPlan, track: TrackedMedia?) {
        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.kind)
        if target == .own, isNaming(plan.kind) {
            throw ResolveError.trackOwnOnNamingClip(place: place, kind: kind)
        }
        if target == .own, area == nil, mask == nil {
            throw ResolveError.trackOwnWithoutArea(place: place, kind: kind)
        }
        guard let parent = plan.parent, let picture = picture(of: parent, in: time) else {
            throw ResolveError.trackWithoutVideo(place: place, kind: kind)
        }

        // Only a mask in the parent's space lies in the media followed; a box shape's is in its own box.
        let ownMask = plan.space == .parent
            ? mask.map { self.area(of: $0, on: picture.clock, instant: plan.instant) }
            : nil
        let start = try self.target(
            target,
            candidates: [
                ("area", area),
                ("mask", ownMask)
            ],
            in: picture.picture,
            at: plan.instant,
            on: picture.clock,
            place: place,
            kind: kind
        )
        let followed = try follow(
            start.area,
            at: start.instant,
            on: picture.clock,
            drawn: drawn(under: parent, of: plan, in: time),
            file: picture.file,
            fps: fps
        )

        return (
            try narrowed(plan, to: followed.range, place: written.place),
            TrackedMedia(track: followed.track, file: picture.file, clock: picture.clock)
        )
    }

    // A connected or sequence clip is visible only where its target was followed (FRAMES-12).
    private func narrowed(
        _ plan: ClipPlan,
        to followed: TimeRange,
        place: Place
    ) throws -> ClipPlan {
        guard let visible = plan.visible.intersection(followed) else {
            throw ResolveError.neverFollowed(place: place, kind: .clip(plan.kind), visible: plan.visible)
        }

        return plan.narrowed(to: visible)
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
        on clock: MediaClock,
        instant: Double
    ) -> PropertyValue<FoundArea> {
        let found = { (masks: [ResolvedMask], time: Double) in
            let bounds = masks.bounds ?? Rectangle(x: 0, y: 0, width: 0, height: 0)
            return FoundArea(
                rectangle: bounds,
                target: bounds,
                mediaTime: clock.mediaTime(atSequenceTime: time),
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

    // The target before padding and the sequence time it is found at, the tracked clip's instant (FRAMES-12): for
    // `true` the one of the clip's own candidates it has, at its first keyframe or else at the clip's instant, and
    // otherwise the area it names, found at the clip's instant. A named target does not look at the candidates.
    private func target(
        _ target: TrackTarget,
        candidates: [(key: String, value: PropertyValue<FoundArea>?)],
        in picture: Picture,
        at instant: Double,
        on clock: MediaClock,
        place: Place,
        kind: PlaceKind
    ) throws -> (area: FoundArea, instant: Double) {
        switch target {
        case .own:
            guard let own = try own(candidates, place: place, kind: kind) else {
                throw ResolveError.trackOwnWithoutArea(place: place, kind: kind)
            }

            return (own.firstValue, own.first?.at ?? instant)

        case let .area(form):
            let mediaTime = clock.mediaTime(atSequenceTime: instant)
            return (try finder.area(form, in: picture, atMediaTime: mediaTime, place: place, kind: kind.label), instant)
        }
    }

    // Follows the target found at the sequence time `instant` over every media frame the clock shows on the frames
    // it draws and those between them and the target's frame: with holds and reverse, the lowest to the highest media
    // time shown. The range comes back in sequence time, open on a side where nothing needed was lost.
    private func follow(
        _ target: FoundArea,
        at instant: Double,
        on clock: MediaClock,
        drawn: TimeRange,
        file: MediaFile,
        fps: Double
    ) throws -> (track: Track, range: TimeRange) {
        let shown = shownMediaTimes(on: clock, drawn: drawn, fps: fps)
        let firstShown = shown.min() ?? target.mediaTime
        let lastShown = shown.max() ?? target.mediaTime
        let firstNeeded = file.frameTime(at: min(firstShown, target.mediaTime)) ?? firstShown
        let lastNeeded = max(lastShown, target.mediaTime)
        let quad = Quad(target.target)
        let frames = try tracker.track(quad, in: file, atMediaTime: target.mediaTime, over: firstNeeded...lastNeeded)
        let track = Track(target: quad, mediaTime: target.mediaTime, frames: frames)
        guard let first = frames.first, let last = frames.last else {
            return (track, TimeRange(start: instant, end: instant))
        }

        let next = file.frameTime(after: last.time)
        let isStartLost = first.time > firstNeeded
        let isEndLost = next.map { $0 <= lastNeeded } ?? false
        guard isStartLost || isEndLost else { return (track, TimeRange(start: -.infinity, end: .infinity)) }

        // A clock whose media time moves one way turns the frames lost back into sequence time.
        if
            let start = isStartLost ? clock.sequenceTime(ofMediaTime: first.time) : -Double.infinity,
            let end = isEndLost ? next.flatMap(clock.sequenceTime(ofMediaTime:)) : Double.infinity
        {
            return (track, TimeRange(start: start, end: end))
        }

        let firstFollowed = file.frameIndex(at: first.time)
        let lastFollowed = file.frameIndex(at: last.time)
        let followed = { (frame: Int) in
            let shownFrame = file.frameIndex(at: clock.mediaTime(atSequenceTime: Double(frame) / fps))
            return firstFollowed <= shownFrame && shownFrame <= lastFollowed
        }
        return (track, followedRange(around: instant, on: drawn, fps: fps, where: followed))
    }

    // The media times a clock shows on the frames of a drawn range and at its ends.
    private func shownMediaTimes(
        on clock: MediaClock,
        drawn: TimeRange,
        fps: Double
    ) -> [Double] {
        let first = Int((drawn.start * fps).rounded(.up))
        let last = Int((drawn.end * fps).rounded(.down))
        let frames = stride(from: first, through: last, by: 1)
        let times = [drawn.start] + frames.map { Double($0) / fps } + [drawn.end]

        return times.map(clock.mediaTime(atSequenceTime:))
    }

    // The frames walked out from the one at `instant` while each shows a followed frame, as a sequence range: a
    // remapped clip's media time need not move one way, so the frames shown cannot be turned back through its line.
    private func followedRange(
        around instant: Double,
        on drawn: TimeRange,
        fps: Double,
        where isFollowed: (Int) -> Bool
    ) -> TimeRange {
        let firstFrame = Int((drawn.start * fps).rounded(.up))
        let lastFrame = Int((drawn.end * fps).rounded(.up)) - 1
        let instantFrame = min(max(Int((instant * fps).rounded(.down)), firstFrame), lastFrame)
        guard isFollowed(instantFrame) else { return TimeRange(start: instant, end: instant) }

        var start = instantFrame
        while start > firstFrame, isFollowed(start - 1) {
            start -= 1
        }
        var end = instantFrame
        while end < lastFrame, isFollowed(end + 1) {
            end += 1
        }

        return TimeRange(
            start: start == firstFrame ? -.infinity : Double(start) / fps,
            end: end == lastFrame ? .infinity : Double(end + 1) / fps
        )
    }

    // The video or image sequence a storyline clip plays, which a tracker can follow, and nil for a still, a solid or
    // a compound clip.
    private func picture(of plan: StorylinePlan) -> (picture: Picture, file: MediaFile, clock: MediaClock)? {
        guard
            plan.source.kind == .media(.video),
            let media = plan.source.media,
            case let .file(file) = media.source,
            let size = file.size,
            let clock = plan.clock
        else {
            return nil
        }

        return (Picture(name: media.reference ?? file.path, source: .mediaFile(file), size: size), file, clock)
    }

    // The video or image sequence a connected or sequence media clip plays, nil for any other clip.
    private func picture(of plan: ClipPlan) -> (picture: Picture, file: MediaFile, clock: MediaClock)? {
        guard
            plan.kind == .media(.video),
            let media = plan.media,
            case let .file(file) = media.source,
            let size = file.size,
            let clock = plan.mediaClock
        else {
            return nil
        }

        return (Picture(name: media.reference ?? file.path, source: .mediaFile(file), size: size), file, clock)
    }

    private func picture(
        of parent: ClipParent,
        in time: TimePlan
    ) -> (picture: Picture, file: MediaFile, clock: MediaClock)? {
        switch parent {
        case let .storyline(index, _):
            picture(of: time.storyline[index])

        case let .clip(index, _):
            picture(of: time.clips[index])
        }
    }

    private func drawn(
        under parent: ClipParent,
        of plan: ClipPlan,
        in time: TimePlan
    ) -> TimeRange {
        switch parent {
        case let .storyline(index, _):
            time.storyline[index].drawn

        case .clip:
            plan.visible
        }
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
