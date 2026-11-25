//
//  TrackPlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what `track` follows (FRAMES-12). A clip's track data names the track's frame by its `time` and gives the
// target's quad on every frame followed, in the tracked media: a storyline or media clip's own video or image sequence
// and any other clip's parent's. Resolve fits each frame's motion to the quads, through the clock of the tracked media's
// clip. A storyline clip whose data does not cover its edit range stops, and a connected or sequence clip is visible
// only on the frames followed, narrowed from its instant.
struct TrackPlanner: Sendable {
    // MARK: - Property
    // Sequence times are sums and quotients of media times, so a frame boundary may miss an edit point by rounding.
    private static let tolerance = 1e-9

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func plan(_ time: TimePlan) throws -> TrackPlan {
        let storyline = try time.storyline.indices.map { index in
            try track(time.storyline[index], written: time.sequence.storyline[index], fps: time.fps)
        }

        let written = time.sequence.storyline.flatMap(\.connected) + time.sequence.clips
        let clips = try time.clips.indices.map { index in
            try track(time.clips[index], written: written[index], time: time, fps: time.fps)
        }

        return TrackPlan(time: time.replacingClips(clips.map(\.plan)), storyline: storyline, clips: clips.map(\.track))
    }

    // The media a storyline clip's track follows: its own video or image sequence, needed where it is drawn, and nil
    // for a still, a solid or a compound clip.
    func source(of plan: StorylinePlan) -> TrackSource? {
        media(of: plan).map { media in
            TrackSource(place: plan.place, file: media.file, clock: media.clock, drawn: plan.drawn)
        }
    }

    // The media a connected or sequence clip's track follows: a media clip of video or image sequence without a corner
    // pin follows its own, needed while it is visible, and any other clip, one with a corner pin included, its
    // parent's, which must be the video or image sequence of a storyline clip or of a connected or sequence media clip
    // without a corner pin. Under a storyline clip it is needed where that clip is drawn, and under any other parent
    // while the clip is visible. Nil where there is none to follow.
    func source(
        of plan: ClipPlan,
        in time: TimePlan
    ) -> TrackSource? {
        if !plan.isPinned, let media = media(of: plan) {
            return TrackSource(place: plan.place, file: media.file, clock: media.clock, drawn: plan.visible)
        }
        guard let parent = plan.parent, let media = media(of: parent, in: time) else { return nil }

        let place = switch parent {
        case let .storyline(index, _):
            time.storyline[index].place

        case let .clip(index, _):
            time.clips[index].place
        }
        return TrackSource(
            place: place,
            file: media.file,
            clock: media.clock,
            drawn: drawn(under: parent, of: plan, in: time)
        )
    }

    // The timestamps of the first and the last frame of the media a track follows that its clock shows over the range
    // it is needed, which `timeline` reports as `tracked`.
    func shownFrames(
        of source: TrackSource,
        fps: Double
    ) -> ClosedRange<Double> {
        let shown = shownMediaTimes(on: source.clock, drawn: source.drawn, fps: fps)
        let first = shown.min() ?? 0
        let last = shown.max() ?? 0
        return (source.file.frameTime(at: first) ?? first)...(source.file.frameTime(at: last) ?? last)
    }

    // MARK: - Private
    private func track(
        _ plan: StorylinePlan,
        written: StorylineClip,
        fps: Double
    ) throws -> Track? {
        guard let data = written.track else { return nil }

        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.source.kind)
        guard let source = source(of: plan) else { throw ResolveError.trackWithoutVideo(place: place, kind: kind) }

        let followed = try self.followed(data, in: source, at: plan.instant, fps: fps, place: place, kind: kind)
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

    private func track(
        _ plan: ClipPlan,
        written: Clip,
        time: TimePlan,
        fps: Double
    ) throws -> (plan: ClipPlan, track: TrackedMedia?) {
        guard let data = written.track else { return (plan, nil) }

        let place = written.place.appending(key: "track")
        let kind = PlaceKind.clip(plan.kind)
        guard let source = source(of: plan, in: time) else { throw ResolveError.trackWithoutVideo(place: place, kind: kind) }

        let followed = try self.followed(data, in: source, at: plan.instant, fps: fps, place: place, kind: kind)
        try checkInstant(of: plan, followedBy: followed.track, in: source, place: place)

        return (
            try narrowed(plan, to: followed.range, place: written.place),
            TrackedMedia(track: followed.track, file: source.file, clock: source.clock)
        )
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

    // Track data as the track it gives and the sequence range it is followed over: each frame at the timestamp of the
    // media frame it names, and the target the quad of the frame `time` names. A written quad is a value, so a frame out
    // of order, two frames on one media frame, a gap, a quad that is not strictly convex or runs the other way round than
    // the target, and a `time` that names no frame of the data stop.
    private func followed(
        _ data: TrackData,
        in source: TrackSource,
        at instant: Double,
        fps: Double,
        place: Place,
        kind: PlaceKind
    ) throws -> (track: Track, range: TimeRange) {
        let file = source.file
        let refuse = { (index: Int?, reason: TrackDataRefusal) in
            ResolveError.trackData(
                place: index.map { place.appending(key: "frames").appending(index: $0) } ?? place,
                kind: kind,
                reason: reason
            )
        }
        let frames = data.frames
        let targetTime = try trackFrameTime(data.time, in: file, place: place, kind: kind)
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
        let shown = shownMediaTimes(on: source.clock, drawn: source.drawn, fps: fps)
        return range(
            of: Track(target: target, mediaTime: targetTime, frames: tracked),
            needed: needed(shown: shown, from: targetTime, in: file),
            at: instant,
            on: source.clock,
            drawn: source.drawn,
            file: file,
            fps: fps
        )
    }

    // A clip can show at its instant a frame its track data does not name, and its window, narrowed from its instant,
    // would hold none.
    private func checkInstant(
        of plan: ClipPlan,
        followedBy track: Track,
        in source: TrackSource,
        place: Place
    ) throws {
        let mediaTime = source.clock.mediaTime(atSequenceTime: plan.instant)
        let shown = source.file.frameIndex(at: mediaTime)
        guard !track.samples.contains(where: { source.file.frameIndex(at: $0.time) == shown }) else { return }

        throw ResolveError.instantNotFollowed(
            place: place,
            kind: .clip(plan.kind),
            mediaTime: source.file.frameTime(at: mediaTime) ?? mediaTime
        )
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

    // The video or image sequence a storyline clip plays, which has frames to follow, and nil for a still, a solid or
    // a compound clip.
    private func media(of plan: StorylinePlan) -> (file: MediaFile, clock: MediaClock)? {
        guard
            plan.source.kind == .media(.video),
            let media = plan.source.media,
            case let .file(file) = media.source,
            let clock = plan.clock
        else {
            return nil
        }

        return (file, clock)
    }

    // The video or image sequence a connected or sequence media clip plays, nil for any other clip.
    private func media(of plan: ClipPlan) -> (file: MediaFile, clock: MediaClock)? {
        guard
            plan.kind == .media(.video),
            let media = plan.media,
            case let .file(file) = media.source,
            let clock = plan.mediaClock
        else {
            return nil
        }

        return (file, clock)
    }

    private func media(
        of parent: ClipParent,
        in time: TimePlan
    ) -> (file: MediaFile, clock: MediaClock)? {
        switch parent {
        case let .storyline(index, _):
            time.sequence.storyline[index].cornerPin == nil ? media(of: time.storyline[index]) : nil

        case let .clip(index, _):
            time.clips[index].isPinned ? nil : media(of: time.clips[index])
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

    // The followed range as a message shows it, within what the storyline clip draws.
    private func shown(
        _ range: TimeRange,
        in plan: StorylinePlan
    ) -> TimeRange {
        TimeRange(start: max(range.start, plan.drawn.start), end: min(range.end, plan.drawn.end))
    }
}
