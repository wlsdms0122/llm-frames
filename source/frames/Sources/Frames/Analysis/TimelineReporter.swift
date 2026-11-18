//
//  TimelineReporter.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// Plans a sequence without rendering and reports its time as `timeline` prints it, with every window as tracking
// leaves it. It stops wherever the plan does. A resolved document is reported as it is written: it keeps no names, so
// its presets are nil and its media is the pinned file, and it holds an audio clip only as sound, so it reports none.
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
        arguments: ArgumentFile? = nil
    ) throws -> TimelineReport {
        report(of: try planner.plan(document, theme: theme, arguments: arguments))
    }

    func report(of plan: SequencePlan) -> TimelineReport {
        let time = plan.time

        return TimelineReport(
            duration: time.duration,
            storyline: time.storyline.indices.map { index in
                entry(of: time.storyline[index], geometry: plan.storyline[index])
            },
            clips: time.clips.indices.map { index in
                entry(of: time.clips[index], geometry: plan.clips[index], time: time)
            }
        )
    }

    package func report(of sequence: ResolvedSequence) -> TimelineReport {
        let storyline = sequence.storyline

        return TimelineReport(
            duration: sequence.format.duration,
            storyline: storyline.indices.map { index in
                entry(of: storyline[index], outgoing: storyline.indices.contains(index + 1) ? storyline[index + 1] : nil)
            },
            clips: sequence.clips.map { entry(of: $0, sequence: sequence) }
        )
    }

    // MARK: - Private
    private func entry(
        of clip: StorylinePlan,
        geometry: StorylineGeometry
    ) -> TimelineStorylineEntry {
        TimelineStorylineEntry(
            place: clip.place.description,
            id: clip.id,
            media: clip.source.media?.reference,
            edit: clip.edit,
            drawn: clip.drawn,
            clip: clip.source.clipRange,
            speed: clip.source.speed,
            transition: clip.transition.map { TimelineTransition(preset: $0.preset, seconds: $0.seconds) },
            nested: geometry.nested.map { report(of: $0) }
        )
    }

    private func entry(
        of clip: ClipPlan,
        geometry: ClipGeometry,
        time: TimePlan
    ) -> TimelineClipEntry {
        let animation = clip.animation
        let parent: String? = switch clip.parent {
        case let .storyline(index, _):
            time.storyline[index].place.description

        case let .clip(index, _):
            time.clips[index].place.description

        case nil:
            nil
        }

        return TimelineClipEntry(
            place: clip.place.description,
            id: clip.id,
            kind: clip.kind.label,
            visible: clip.visible,
            lane: clip.lane,
            parent: parent,
            animation: animation.isEmpty
                ? nil
                : TimelineAnimation(
                    entrance: animation.entrance.map(span),
                    loop: animation.loop.map(span),
                    exit: animation.exit.map(span)
                ),
            nested: geometry.nested.map { report(of: $0) }
        )
    }

    private func span(_ span: PresetSpan) -> TimelineSpan {
        TimelineSpan(preset: span.preset, length: span.span.length)
    }

    // A clip is drawn from the start of its incoming transition to the end of its outgoing one.
    private func entry(
        of clip: ResolvedStorylineClip,
        outgoing: ResolvedStorylineClip?
    ) -> TimelineStorylineEntry {
        let edit = TimeRange(start: clip.start, end: clip.end)
        let drawn = TimeRange(
            start: clip.transition?.start ?? clip.start,
            end: outgoing?.transition?.end ?? clip.end
        )

        return TimelineStorylineEntry(
            place: clip.place,
            id: clip.id,
            media: clip.media.flatMap(file(of:)),
            edit: edit,
            drawn: drawn,
            clip: TimeRange(start: clip.in, end: clip.out),
            speed: clip.speed,
            transition: clip.transition.map { TimelineTransition(preset: nil, seconds: $0.end - $0.start) },
            nested: clip.media.flatMap(nestedReport(of:))
        )
    }

    private func entry(
        of clip: ResolvedClip,
        sequence: ResolvedSequence
    ) -> TimelineClipEntry {
        let animation = clip.animation
        let parent = clip.parent.flatMap { id in
            sequence.storyline.first { $0.id == id }?.place ?? sequence.clips.first { $0.id == id }?.place
        }
        let media: ResolvedMediaContent? = if case let .media(media) = clip.content { media.media } else { nil }

        return TimelineClipEntry(
            place: clip.place,
            id: clip.id,
            kind: kind(of: clip.content),
            visible: TimeRange(start: clip.start, end: clip.end),
            lane: clip.lane,
            parent: parent,
            animation: animation == .none
                ? nil
                : TimelineAnimation(
                    entrance: animation.entrance.map(span),
                    loop: animation.loop.map(span),
                    exit: animation.exit.map(span)
                ),
            nested: media.flatMap(nestedReport(of:))
        )
    }

    private func span(_ span: AnimationSpan) -> TimelineSpan {
        TimelineSpan(preset: nil, length: span.length)
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

            case .pinned:
                ClipKind.media(clip.timing == nil ? .image : .video).label
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
        }
    }

    private func nestedReport(of media: ResolvedMediaContent) -> TimelineReport? {
        guard case let .nested(sequence) = media else { return nil }

        return report(of: sequence)
    }
}
