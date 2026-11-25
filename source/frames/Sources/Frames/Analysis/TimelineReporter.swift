//
//  TimelineReporter.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Plans a sequence without rendering and reports its time as `timeline` prints it, with every window as tracking
// leaves it. It stops wherever the plan does. A resolved document is reported as it is written: it keeps no names, so
// its presets are nil, it holds an audio clip only as sound, so it reports none, it writes every instant in sequence
// time and keeps no clip's instant, and it pins an image sequence's frame times and no rate. Media is named by its pinned
// path in both. Asked at a sequence time, which may lie outside the sequence, every entry also gives what its time map
// gives there (FRAMES-8), and a nested document is reported at the media time its clip shows.
package struct TimelineReporter: Sendable {
    // MARK: - Property
    private let planner: DocumentPlanner

    // MARK: - Initializer
    package init(planner: DocumentPlanner) {
        self.planner = planner
    }

    // MARK: - Public
    package func report(
        of document: JSONValue,
        theme: String? = nil,
        arguments: ArgumentFile? = nil,
        at time: Double? = nil
    ) throws -> TimelineReport {
        report(of: try planner.plan(document, theme: theme, arguments: arguments), at: time)
    }

    func report(
        of plan: SequencePlan,
        at time: Double? = nil
    ) -> TimelineReport {
        let timePlan = plan.time

        return TimelineReport(
            duration: timePlan.duration,
            time: time,
            storyline: timePlan.storyline.indices.map { index in
                let clip = timePlan.storyline[index]
                return entry(
                    of: clip,
                    geometry: plan.storyline[index],
                    sound: sound(at: clip.place, in: plan),
                    ownSpace: timePlan.ownSpace(of: clip),
                    at: time
                )
            },
            clips: timePlan.clips.indices.map { index in
                let clip = timePlan.clips[index]
                let isVisualMedia = if case let .media(kind) = clip.kind { kind != .audio } else { false }
                let range = isVisualMedia ? sound(at: clip.place, in: plan) : nil
                return entry(of: clip, geometry: plan.clips[index], sound: range, plan: timePlan, at: time)
            }
        )
    }

    package func report(
        of sequence: ResolvedSequence,
        at time: Double? = nil
    ) -> TimelineReport {
        let storyline = sequence.storyline

        return TimelineReport(
            duration: sequence.format.duration,
            time: time,
            storyline: storyline.indices.map { index in
                entry(
                    of: storyline[index],
                    outgoing: storyline.indices.contains(index + 1) ? storyline[index + 1] : nil,
                    sound: sound(at: storyline[index].place, in: sequence),
                    ownSpace: sequence.ownSpace(of: storyline[index]),
                    at: time
                )
            },
            clips: sequence.clips.map { entry(of: $0, sequence: sequence, at: time) }
        )
    }

    // MARK: - Private
    private func sound(
        at place: Place,
        in plan: SequencePlan
    ) -> TimeRange? {
        plan.sound.first { $0.place == place }?.range
    }

    private func entry(
        of clip: StorylinePlan,
        geometry: StorylineGeometry,
        sound: TimeRange?,
        ownSpace: CoordinateSpace,
        at time: Double?
    ) -> TimelineStorylineEntry {
        let media = clip.source.media
        let shown = time.map { time in
            TimelineStorylineTime(
                clipTime: clip.map.clipTime(atSequenceTime: time),
                mediaTime: media.map { shownTime(of: $0, at: clip.mediaTime(atSequenceTime: time)) }
            )
        }

        return TimelineStorylineEntry(
            place: clip.place.description,
            id: clip.id,
            kind: clip.source.kind.label,
            media: media.flatMap(file(of:)),
            page: media.flatMap(page(of:)),
            fps: media.flatMap(rate(of:)),
            instant: clip.instant,
            clock: TimelineClock(clip: clip.place.description, map: clip.map),
            space: .output,
            ownSpace: ownSpace,
            edit: clip.edit,
            drawn: clip.drawn,
            clip: clip.source.clipRange,
            sound: sound,
            speed: clip.source.speed,
            isTimeRemapped: clip.timeRemap != nil,
            transition: clip.transition.map { TimelineTransition(preset: $0.preset, seconds: $0.seconds) },
            time: shown,
            nested: geometry.nested.map { report(of: $0, at: shown?.mediaTime) }
        )
    }

    // A media clip without a clock is a still, and an audio clip has no picture, so it writes no coordinates.
    private func entry(
        of clip: ClipPlan,
        geometry: ClipGeometry,
        sound: TimeRange?,
        plan: TimePlan,
        at time: Double?
    ) -> TimelineClipEntry {
        let animation = clip.animation
        let parent: String? = switch clip.parent {
        case let .storyline(index, _):
            plan.storyline[index].place.description

        case let .clip(index, _):
            plan.clips[index].place.description

        case nil:
            nil
        }
        let isSound = clip.kind == .media(.audio)
        let shown = time.map { time in
            TimelineClipTime(mediaTime: clip.media.map { media in
                shownTime(of: media, at: clip.mediaClock?.mediaTime(atSequenceTime: time) ?? 0)
            })
        }

        return TimelineClipEntry(
            place: clip.place.description,
            id: clip.id,
            kind: clip.kind.label,
            media: clip.media.flatMap(file(of:)),
            page: clip.media.flatMap(page(of:)),
            fps: clip.media.flatMap(rate(of:)),
            instant: clip.instant,
            clock: TimelineClock(clip: clip.storyline.map { plan.storyline[$0].place.description }, map: clip.clock),
            space: isSound ? nil : plan.space(givenBy: clip.parent),
            ownSpace: isSound ? nil : plan.ownSpace(of: clip),
            visible: clip.visible,
            sound: sound,
            lane: clip.lane,
            storyline: clip.storyline.map { plan.storyline[$0].place.description },
            parent: parent,
            animation: animation.isEmpty
                ? nil
                : TimelineAnimation(
                    entrance: animation.entrance.map(span),
                    loop: animation.loop.map(span),
                    exit: animation.exit.map(span),
                    units: animation.units
                ),
            time: shown,
            nested: geometry.nested.map { report(of: $0, at: shown?.mediaTime) }
        )
    }

    private func span(_ span: PresetSpan) -> TimelineSpan {
        TimelineSpan(preset: span.preset, length: span.span.length)
    }

    // A resolved document holds an audio clip only as sound, so every clip it draws from media is visual media.
    private func sound(
        at place: String,
        in sequence: ResolvedSequence
    ) -> TimeRange? {
        sequence.audio.first { $0.place == place }.map { TimeRange(start: $0.start, end: $0.end) }
    }

    // A clip is drawn from the start of its incoming transition to the end of its outgoing one.
    private func entry(
        of clip: ResolvedStorylineClip,
        outgoing: ResolvedStorylineClip?,
        sound: TimeRange?,
        ownSpace: CoordinateSpace,
        at time: Double?
    ) -> TimelineStorylineEntry {
        let edit = TimeRange(start: clip.start, end: clip.end)
        let drawn = TimeRange(
            start: clip.transition?.start ?? clip.start,
            end: outgoing?.transition?.end ?? clip.end
        )
        let shown = time.map { time in
            TimelineStorylineTime(
                clipTime: clip.map.clipTime(atSequenceTime: time),
                mediaTime: clip.media.map { shownTime(of: $0, at: clip.mediaTime(at: time)) }
            )
        }

        return TimelineStorylineEntry(
            place: clip.place,
            id: clip.id,
            kind: (clip.media.map { ClipKind.media(kind(of: $0)) } ?? .solid).label,
            media: clip.media.flatMap(file(of:)),
            page: clip.media.flatMap(page(of:)),
            fps: nil,
            instant: nil,
            clock: .sequence,
            space: .output,
            ownSpace: ownSpace,
            edit: edit,
            drawn: drawn,
            clip: TimeRange(start: clip.in, end: clip.out),
            sound: sound,
            speed: clip.speed,
            isTimeRemapped: clip.timeRemap != nil,
            transition: clip.transition.map { TimelineTransition(preset: nil, seconds: $0.end - $0.start) },
            time: shown,
            nested: clip.media.flatMap { nestedReport(of: $0, at: shown?.mediaTime) }
        )
    }

    private func entry(
        of clip: ResolvedClip,
        sequence: ResolvedSequence,
        at time: Double?
    ) -> TimelineClipEntry {
        let animation = clip.animation
        let parent = clip.parent.flatMap { id in
            sequence.storyline.first { $0.id == id }?.place ?? sequence.clips.first { $0.id == id }?.place
        }
        let media: ResolvedMediaClip? = if case let .media(media) = clip.content { media } else { nil }
        let shown = time.map { time in
            TimelineClipTime(mediaTime: media.map { shownTime(of: $0.media, at: $0.mediaTime(at: time)) })
        }

        return TimelineClipEntry(
            place: clip.place,
            id: clip.id,
            kind: kind(of: clip.content),
            media: media.flatMap { file(of: $0.media) },
            page: media.flatMap { page(of: $0.media) },
            fps: nil,
            instant: nil,
            clock: .sequence,
            space: sequence.space(givenBy: clip.parent),
            ownSpace: sequence.ownSpace(of: clip),
            visible: TimeRange(start: clip.start, end: clip.end),
            sound: media == nil ? nil : sound(at: clip.place, in: sequence),
            lane: clip.lane,
            storyline: clip.storyline.map { sequence.storyline[$0].place },
            parent: parent,
            animation: animation == .none
                ? nil
                : TimelineAnimation(
                    entrance: animation.entrance.map(span),
                    loop: animation.loop.map(span),
                    exit: animation.exit.map(span),
                    units: animation.units
                ),
            time: shown,
            nested: media.flatMap { nestedReport(of: $0.media, at: shown?.mediaTime) }
        )
    }

    private func span(_ span: AnimationSpan) -> TimelineSpan {
        TimelineSpan(preset: nil, length: span.length)
    }

    // The kind of a storyline clip's media, as far as what it shows tells it: a pinned medium without frame times is a
    // still.
    private func kind(of media: ResolvedMediaContent) -> MediaKind {
        switch media {
        case .nested:
            .sequence

        case let .pinned(pinned):
            pinned.page != nil ? .page : pinned.frameTimes.isEmpty ? .image : .video
        }
    }

    // The kind a clip was written as, as far as what it draws tells it: a media clip without timing shows a still.
    private func kind(of content: ResolvedClipContent) -> String {
        switch content {
        case .title:
            ClipKind.title.label

        case let .shape(shape):
            ClipKind.shape(shape.kind.rawValue).label

        case .adjustment:
            ClipKind.adjust.label

        case let .media(clip):
            switch clip.media {
            case .nested:
                ClipKind.media(.sequence).label

            case let .pinned(media):
                ClipKind.media(clip.timing != nil ? .video : media.page != nil ? .page : .image).label
            }
        }
    }

    // An image sequence is pinned as its frame files, so it is named by the directory that holds them.
    private func file(of media: ResolvedMediaContent) -> String? {
        guard case let .pinned(pinned) = media else { return nil }

        switch pinned.source {
        case let .file(file):
            return file.path

        case let .imageSequence(files):
            return files.first.map { URL(fileURLWithPath: $0.path).deletingLastPathComponent().path }

        case let .page(file, _):
            return file.path
        }
    }

    // The media time an entry gives where its time map gives `mediaTime`: the pinned time of the frame shown there, the
    // one `evaluate` names (FRAMES-23), 0 for a still, which has one picture, and `mediaTime` itself for a nested
    // sequence, which picks no frame of its own, and for sound, which has no frames.
    private func shownTime(
        of media: MediaPlan,
        at mediaTime: Double
    ) -> Double {
        guard case let .file(file) = media.source, media.kind != .audio else { return mediaTime }

        return file.frameTime(at: mediaTime) ?? 0
    }

    private func shownTime(
        of media: ResolvedMediaContent,
        at mediaTime: Double
    ) -> Double {
        guard case let .pinned(pinned) = media else { return mediaTime }

        return pinned.frameTime(at: mediaTime) ?? 0
    }

    // A nested sequence has no file of its own.
    private func file(of media: MediaPlan) -> String? {
        guard case let .file(file) = media.source else { return nil }

        return file.path
    }

    // An image sequence is read at the rate its media form writes, and every other medium's files give its rate.
    private func rate(of media: MediaPlan) -> Double? {
        guard case let .file(file) = media.source, !file.frameFiles.isEmpty else { return nil }

        return file.fps
    }

    private func page(of media: MediaPlan) -> Int? {
        guard case let .file(file) = media.source else { return nil }

        return file.page
    }

    private func page(of media: ResolvedMediaContent) -> Int? {
        guard case let .pinned(pinned) = media else { return nil }

        return pinned.page
    }

    private func nestedReport(
        of media: ResolvedMediaContent,
        at time: Double?
    ) -> TimelineReport? {
        guard case let .nested(sequence) = media else { return nil }

        return report(of: sequence, at: time)
    }
}
