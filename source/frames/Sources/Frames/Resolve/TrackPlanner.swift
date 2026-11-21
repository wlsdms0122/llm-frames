//
//  TrackPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what `track` follows (FRAMES-12). The target is found before padding on the track's frame, the frame a `track`
// object's `time` names or else the one the clip's instant shows, and the tracker follows it from there in the tracked
// media, a storyline or media clip's own video or image sequence and any other clip's parent's, over every frame the
// clip can show and the frames between them and the track's frame: a storyline clip's handles included, and through
// the clock of the tracked media's clip. Track data gives the frames in place of the tracker. A storyline clip that
// loses its target inside its edit range stops, and a connected or sequence clip is visible only on the frames followed,
// narrowed from its instant.
struct TrackPlanner: Sendable {
    // MARK: - Property
    // Sequence times are sums and quotients of media times, so a frame boundary may miss an edit point by rounding.
    private static let tolerance = 1e-9

    private let follower: TargetFollower
    private let finder: AreaFinder

    // MARK: - Initializer
    init(
        tracker: any TrackerProvider,
        ocr: any OCRProvider,
        languages: [LanguageTag]?
    ) {
        self.follower = TargetFollower(tracker: tracker)
        self.finder = AreaFinder(ocr: ocr, languages: languages)
    }

    // MARK: - Public
    // `storylineCrops` and `storylineMasks` are what was found for each storyline clip's crop and mask, and `crops`,
    // `areas`, `masks` and `cornerPins` for each other clip's crop, area, mask and corner pin, in the time plan's order,
    // which `true` follows.
    func plan(
        _ time: TimePlan,
        storylineCrops: [PropertyValue<FoundArea>?],
        storylineMasks: [[ResolvedMask]?],
        crops: [PropertyValue<FoundArea>?],
        areas: [PropertyValue<AreaValue>?],
        masks: [[ResolvedMask]?],
        cornerPins: [PropertyValue<[GeometryPoint]>?]
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
                area: try ownArea(areas[index], of: time.clips[index], written: written[index]),
                mask: masks[index],
                cornerPin: try ownCornerPin(cornerPins[index], of: time.clips[index], written: written[index]),
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
        mask: [ResolvedMask]?,
        fps: Double
    ) throws -> Track? {
        guard let target = written.track else { return nil }

        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.source.kind)
        guard let picture = picture(of: plan) else { throw ResolveError.trackWithoutVideo(place: place, kind: kind) }

        let followed = try self.followed(
            target,
            candidates: [
                ("crop", isArea(written.crop) ? crop : nil),
                ("mask", mask.map { self.area(of: $0, on: picture.clock, instant: plan.instant) })
            ],
            in: picture,
            at: plan.instant,
            drawn: plan.drawn,
            fps: fps,
            place: place,
            kind: kind
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

    // A media clip of video or image sequence without a corner pin follows its own media, where `true` follows its
    // area crop or its mask, and the frames needed are those its clock shows while it is visible. Any other clip, one
    // with a corner pin included, follows its parent's media.
    private func track(
        _ plan: ClipPlan,
        written: Clip,
        crop: PropertyValue<FoundArea>?,
        area: PropertyValue<FoundArea>?,
        mask: [ResolvedMask]?,
        cornerPin: PropertyValue<Quad>?,
        time: TimePlan,
        fps: Double
    ) throws -> (plan: ClipPlan, track: TrackedMedia?) {
        guard let target = written.track else { return (plan, nil) }

        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.kind)
        guard !plan.isPinned, let picture = picture(of: plan) else {
            return try trackInParent(
                plan,
                written: written,
                target: target,
                area: area,
                mask: mask,
                cornerPin: cornerPin,
                time: time,
                fps: fps
            )
        }

        let followed = try self.followed(
            target,
            candidates: [
                ("crop", isArea(written.crop) ? crop : nil),
                ("mask", mask.map { self.area(of: $0, on: picture.clock, instant: plan.instant) })
            ],
            in: picture,
            at: plan.instant,
            drawn: plan.visible,
            fps: fps,
            place: place,
            kind: kind
        )
        try checkInstant(of: plan, followedBy: followed.track, target: target, in: picture, place: place)

        return (
            try narrowed(plan, to: followed.range, place: written.place),
            TrackedMedia(track: followed.track, file: picture.file, clock: picture.clock)
        )
    }

    // `true` belongs to a shape or an adjustment with an area or a mask in its parent's space, or to a clip with a corner
    // pin, whose corner pin is the one geometry of it there (its crop and mask lie on its plane), and a title, still or
    // compound clip without one names what it follows. The parent's media must be the video or image sequence of a
    // storyline clip or of a connected or sequence media clip without a corner pin. The frames needed under a storyline
    // clip are those it draws, and under any other parent those its clock shows while the clip is visible.
    private func trackInParent(
        _ plan: ClipPlan,
        written: Clip,
        target: TrackTarget,
        area: PropertyValue<FoundArea>?,
        mask: [ResolvedMask]?,
        cornerPin: PropertyValue<Quad>?,
        time: TimePlan,
        fps: Double
    ) throws -> (plan: ClipPlan, track: TrackedMedia?) {
        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.kind)
        if target.isOwn, !plan.isPinned, isNaming(plan.kind) {
            throw ResolveError.trackOwnOnNamingClip(place: place, kind: kind)
        }
        if target.isOwn, !plan.isPinned, area == nil, mask == nil {
            throw ResolveError.trackOwnWithoutArea(place: place, kind: kind)
        }
        guard let parent = plan.parent, let picture = picture(of: parent, in: time) else {
            throw ResolveError.trackWithoutVideo(place: place, kind: kind)
        }

        // Only a mask in the parent's space lies in the media followed; a box shape's is in its own box.
        let ownMask = plan.space == .parent && !plan.isPinned
            ? mask.map { self.area(of: $0, on: picture.clock, instant: plan.instant) }
            : nil
        let followed = try self.followed(
            target,
            candidates: [
                ("area", area),
                ("mask", ownMask)
            ],
            cornerPin: cornerPin,
            in: picture,
            at: plan.instant,
            drawn: drawn(under: parent, of: plan, in: time),
            fps: fps,
            place: place,
            kind: kind
        )
        try checkInstant(of: plan, followedBy: followed.track, target: target, in: picture, place: place)

        return (
            try narrowed(plan, to: followed.range, place: written.place),
            TrackedMedia(track: followed.track, file: picture.file, clock: picture.clock)
        )
    }

    // The area `true` may follow, nil where the clip tracks nothing of its own. A clip area is the box of another
    // clip, not a place in the media followed, so it stops there.
    private func ownArea(
        _ area: PropertyValue<AreaValue>?,
        of plan: ClipPlan,
        written: Clip
    ) throws -> PropertyValue<FoundArea>? {
        guard let area, written.track?.isOwn == true else { return nil }

        return try area.map { value in
            guard let found = value.found else {
                throw AreaError.clipAreaInPicture(place: written.place.appending(key: "track"), kind: plan.kind.label)
            }

            return found
        }
    }

    // The quad of the corner pin `true` follows, nil where the clip tracks nothing of its own or has no corner pin. A
    // clip area is the box of another clip, not a place in the media followed, so it stops there.
    private func ownCornerPin(
        _ cornerPin: PropertyValue<[GeometryPoint]>?,
        of plan: ClipPlan,
        written: Clip
    ) throws -> PropertyValue<Quad>? {
        guard let cornerPin, plan.isPinned, written.track?.isOwn == true else { return nil }

        return try cornerPin.map { points in
            guard points.count == 4, points.allSatisfy({ $0.clipArea == nil }) else {
                throw AreaError.clipAreaInPicture(place: written.place.appending(key: "track"), kind: plan.kind.label)
            }

            let corners = points.map(\.fixed)
            return Quad(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3])
        }
    }

    // A connected or sequence clip is visible only where its target was followed.
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

    // What `true` follows: the one of the clip's area, mask and crop it has, each where it starts. A clip with more
    // than one stops, since it must name its target.
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

    // The bounding box of every mask's geometry, without feather, as the area `true` follows. The target is found
    // where the masks start: at the first time a keyframe gives a geometry leaf, a leaf no keyframe moves being at the
    // clip's instant.
    private func area(
        of masks: [ResolvedMask],
        on clock: MediaClock,
        instant: Double
    ) -> PropertyValue<FoundArea> {
        let start = masks.flatMap(\.geometryTimes).min() ?? instant
        let bounds = masks.map { $0.sampled(at: start) }.bounds ?? Rectangle(x: 0, y: 0, width: 0, height: 0)
        let found = FoundArea(
            rectangle: bounds,
            target: bounds,
            mediaTime: clock.mediaTime(atSequenceTime: start),
            lines: []
        )
        guard start != instant else { return .value(found) }

        return .keyframes([PropertyKeyframe(index: 0, at: start, value: found, ease: .linear)])
    }

    // The track of a target in the tracked media and the sequence range it is followed over: track data as written,
    // or the target found on the track's frame and followed by the tracker from there.
    private func followed(
        _ target: TrackTarget,
        candidates: [(key: String, value: PropertyValue<FoundArea>?)],
        cornerPin: PropertyValue<Quad>? = nil,
        in media: (picture: Picture, file: MediaFile, clock: MediaClock),
        at instant: Double,
        drawn: TimeRange,
        fps: Double,
        place: Place,
        kind: PlaceKind
    ) throws -> (track: Track, range: TimeRange) {
        let start: (quad: Quad, mediaTime: Double, instant: Double)
        switch target {
        case let .own(time):
            start = try cornerPin.map { try self.target($0, time: time, on: media, at: instant, place: place, kind: kind) }
                ?? self.target(nil, time: time, candidates: candidates, in: media, at: instant, place: place, kind: kind)

        case let .area(form, time):
            start = try self.target(form, time: time, candidates: [], in: media, at: instant, place: place, kind: kind)

        case let .data(time, frames):
            return try data(
                frames,
                time: time,
                in: media,
                at: instant,
                drawn: drawn,
                fps: fps,
                place: place,
                kind: kind
            )
        }

        return try follow(
            start.quad,
            atMediaTime: start.mediaTime,
            at: start.instant,
            on: media.clock,
            drawn: drawn,
            file: media.file,
            colorSpace: media.picture.colorSpace,
            named: media.picture.name,
            fps: fps,
            place: place,
            kind: kind
        )
    }

    // The target's quad before padding, the media time of the track's frame and the sequence time the window is
    // narrowed from: for `true` the one of the clip's own candidates it has, at its first keyframe or else at the clip's
    // instant, and otherwise the area `form` names, found on the track's frame. With a `time` the track's frame is the
    // frame it names, and the clip's own geometry is static, since a keyframe's value is where it is at its own time. A
    // named target does not look at the candidates.
    private func target(
        _ form: AreaForm?,
        time: Double?,
        candidates: [(key: String, value: PropertyValue<FoundArea>?)],
        in media: (picture: Picture, file: MediaFile, clock: MediaClock),
        at instant: Double,
        place: Place,
        kind: PlaceKind
    ) throws -> (quad: Quad, mediaTime: Double, instant: Double) {
        let frameTime = try time.map { try trackFrameTime($0, in: media.file, place: place, kind: kind) }
        guard let form else {
            guard let own = try own(candidates, place: place, kind: kind) else {
                throw ResolveError.trackOwnWithoutArea(place: place, kind: kind)
            }
            guard let frameTime else {
                return (Quad(own.firstValue.target), own.firstValue.mediaTime, own.first?.at ?? instant)
            }
            guard case let .value(found) = own else { throw ResolveError.trackOwnKeyframed(place: place, kind: kind) }

            return (Quad(found.target), frameTime, instant)
        }

        let mediaTime = frameTime ?? media.clock.mediaTime(atSequenceTime: instant)
        let found = try finder.area(form, in: media.picture, atMediaTime: mediaTime, place: place, kind: kind.label)
        return (Quad(found.target), found.mediaTime, instant)
    }

    // The corner pin of a clip with one, the only geometry `true` follows on it, at its first keyframe or else at the
    // clip's instant, and with a `time` static, on the frame it names.
    private func target(
        _ cornerPin: PropertyValue<Quad>,
        time: Double?,
        on media: (picture: Picture, file: MediaFile, clock: MediaClock),
        at instant: Double,
        place: Place,
        kind: PlaceKind
    ) throws -> (quad: Quad, mediaTime: Double, instant: Double) {
        guard let time else {
            let at = cornerPin.first?.at ?? instant
            return (cornerPin.firstValue, media.clock.mediaTime(atSequenceTime: at), at)
        }
        guard case let .value(quad) = cornerPin else { throw ResolveError.trackOwnKeyframed(place: place, kind: kind) }

        return (quad, try trackFrameTime(time, in: media.file, place: place, kind: kind), instant)
    }

    // The timestamp of the frame of the tracked media whose presentation interval holds `time`: from its timestamp to
    // the next frame's, and for the last frame one frame duration long. A time before the first frame or past the last
    // one names none.
    private func frameTime(
        named time: Double,
        in file: MediaFile
    ) -> Double? {
        let times = file.frameTimes
        let duration = file.fps.map { 1 / $0 } ?? (times.count > 1 ? times[times.count - 1] - times[times.count - 2] : 0)
        guard
            let first = times.first,
            let last = times.last,
            first.roundedTime <= time.roundedTime,
            time.roundedTime < (last + duration).roundedTime || time.roundedTime == last.roundedTime
        else {
            return nil
        }

        return file.frameTime(at: time)
    }

    // The frame the `time` of a `track` object names, which stops naming `...track.time` where it names none.
    private func trackFrameTime(
        _ time: Double,
        in file: MediaFile,
        place: Place,
        kind: PlaceKind
    ) throws -> Double {
        guard let frame = frameTime(named: time, in: file) else {
            throw ResolveError.trackTimeOutside(place: place.appending(key: "time"), kind: kind, time: time)
        }

        return frame
    }

    // Track data as the track it gives: each frame at the timestamp of the media frame it names, and the target the quad
    // of the frame `time` names. A written quad is a value, so a frame out of order, two frames on one media frame, a
    // gap, a quad that is not strictly convex or runs the other way round than the target, and a `time` that names no
    // frame of the data stop. The range is followed as the tracker's frames are.
    private func data(
        _ frames: [TrackDataFrame],
        time: Double,
        in media: (picture: Picture, file: MediaFile, clock: MediaClock),
        at instant: Double,
        drawn: TimeRange,
        fps: Double,
        place: Place,
        kind: PlaceKind
    ) throws -> (track: Track, range: TimeRange) {
        let file = media.file
        let refuse = { (index: Int?, reason: TrackDataRefusal) in
            ResolveError.trackData(
                place: index.map { place.appending(key: "frames").appending(index: $0) } ?? place,
                kind: kind,
                reason: reason
            )
        }
        let targetTime = try trackFrameTime(time, in: file, place: place, kind: kind)
        var times: [Double] = []
        for (index, frame) in frames.enumerated() {
            guard let frameTime = self.frameTime(named: frame.time, in: file) else { throw refuse(index, .outsideMedia) }

            if index > 0 {
                let previous = times[index - 1]
                guard frame.time > frames[index - 1].time else { throw refuse(index, .outOfOrder) }
                guard frameTime.roundedTime != previous.roundedTime else { throw refuse(index, .sameFrame) }
                guard file.frameIndex(at: frameTime) == file.frameIndex(at: previous) + 1 else { throw refuse(index, .gap) }
            }
            times.append(frameTime)
        }
        guard let targetIndex = times.firstIndex(where: { $0.roundedTime == targetTime.roundedTime }) else {
            throw refuse(nil, .noTarget)
        }

        let target = frames[targetIndex].quad
        guard let orientation = target.orientation else { throw refuse(targetIndex, .notConvex) }
        for (index, frame) in frames.enumerated() {
            guard let frameOrientation = frame.quad.orientation else { throw refuse(index, .notConvex) }
            guard frameOrientation == orientation else { throw refuse(index, .otherOrientation) }
        }

        let tracked = zip(times, frames).map { time, frame in TrackedFrame(time: time, quad: frame.quad) }
        let shown = shownMediaTimes(on: media.clock, drawn: drawn, fps: fps)
        return range(
            of: Track(target: target, mediaTime: targetTime, frames: tracked),
            needed: needed(shown: shown, from: targetTime, in: file),
            at: instant,
            on: media.clock,
            drawn: drawn,
            file: file,
            fps: fps
        )
    }

    // A clip whose track names its frame by `time` can show at its instant a frame the track does not follow, and its
    // window, narrowed from its instant, would hold none. With a short form the instant shows the track's frame.
    private func checkInstant(
        of plan: ClipPlan,
        followedBy track: Track,
        target: TrackTarget,
        in media: (picture: Picture, file: MediaFile, clock: MediaClock),
        place: Place
    ) throws {
        guard target.time != nil else { return }

        let mediaTime = media.clock.mediaTime(atSequenceTime: plan.instant)
        let shown = media.file.frameIndex(at: mediaTime)
        guard !track.samples.contains(where: { media.file.frameIndex(at: $0.time) == shown }) else { return }

        throw ResolveError.instantNotFollowed(
            place: place,
            kind: .clip(plan.kind),
            mediaTime: media.file.frameTime(at: mediaTime) ?? mediaTime
        )
    }

    // Follows the target's quad from the track's frame at `mediaTime` over every media frame the clock shows on the
    // frames it draws and those between them and the track's frame: with holds and reverse, the lowest to the highest
    // media time shown. The range comes back in sequence time, narrowed from the clip's `instant`, open on a side where
    // nothing needed was lost.
    private func follow(
        _ target: Quad,
        atMediaTime mediaTime: Double,
        at instant: Double,
        on clock: MediaClock,
        drawn: TimeRange,
        file: MediaFile,
        colorSpace: ColorSpace?,
        named media: String,
        fps: Double,
        place: Place,
        kind: PlaceKind
    ) throws -> (track: Track, range: TimeRange) {
        let shown = shownMediaTimes(on: clock, drawn: drawn, fps: fps)
        let needed = needed(shown: shown, from: mediaTime, in: file)
        let frames = try Result {
            try follower.follow(
                target,
                in: file,
                atMediaTime: mediaTime,
                over: needed,
                colorSpace: colorSpace
            )
        }
        .mapError { error in
            ProviderError.failed(
                provider: .tracker,
                place: place,
                kind: kind.label,
                picture: ProviderPicture(media: media, mediaTime: mediaTime),
                message: "\(error)"
            )
        }
        .get()
        let track = Track(target: target, mediaTime: mediaTime, frames: frames)
        return range(of: track, needed: needed, at: instant, on: clock, drawn: drawn, file: file, fps: fps)
    }

    // The media frames needed: those shown and those between them and the track's frame.
    private func needed(
        shown: [Double],
        from mediaTime: Double,
        in file: MediaFile
    ) -> ClosedRange<Double> {
        let firstShown = shown.min() ?? mediaTime
        let lastShown = shown.max() ?? mediaTime
        let firstNeeded = file.frameTime(at: min(firstShown, mediaTime)) ?? firstShown
        return firstNeeded...max(lastShown, mediaTime)
    }

    // The sequence range a track's frames are followed over, open on a side where nothing needed was lost.
    private func range(
        of track: Track,
        needed: ClosedRange<Double>,
        at instant: Double,
        on clock: MediaClock,
        drawn: TimeRange,
        file: MediaFile,
        fps: Double
    ) -> (track: Track, range: TimeRange) {
        guard let first = track.samples.first, let last = track.samples.last else {
            return (track, TimeRange(start: instant, end: instant))
        }

        let next = file.frameTime(after: last.time)
        let isStartLost = first.time > needed.lowerBound
        let isEndLost = next.map { $0 <= needed.upperBound } ?? false
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

        let picture = Picture(
            name: media.reference ?? file.path,
            source: .mediaFile(file),
            size: size,
            colorSpace: media.colorSpace
        )
        return (picture, file, clock)
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

        let picture = Picture(
            name: media.reference ?? file.path,
            source: .mediaFile(file),
            size: size,
            colorSpace: media.colorSpace
        )
        return (picture, file, clock)
    }

    private func picture(
        of parent: ClipParent,
        in time: TimePlan
    ) -> (picture: Picture, file: MediaFile, clock: MediaClock)? {
        switch parent {
        case let .storyline(index, _):
            time.sequence.storyline[index].cornerPin == nil ? picture(of: time.storyline[index]) : nil

        case let .clip(index, _):
            time.clips[index].isPinned ? nil : picture(of: time.clips[index])
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
