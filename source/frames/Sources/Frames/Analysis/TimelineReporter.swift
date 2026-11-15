//
//  TimelineReporter.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// Plans a sequence's time without rendering and reports it as `timeline` prints it. It stops wherever the plan does.
struct TimelineReporter: Sendable {
    // MARK: - Property
    private let planner: TimePlanner

    // MARK: - Initializer
    init(planner: TimePlanner) {
        self.planner = planner
    }

    // MARK: - Public
    func report(
        of document: JSONValue,
        theme: MergedTheme = .base
    ) throws -> TimelineReport {
        report(of: try planner.plan(document: document, theme: theme))
    }

    func report(of plan: TimePlan) -> TimelineReport {
        TimelineReport(
            duration: plan.duration,
            storyline: plan.storyline.map(entry),
            clips: plan.clips.map { clip in entry(of: clip, storyline: plan.storyline) }
        )
    }

    // MARK: - Private
    private func entry(of clip: StorylinePlan) -> TimelineStorylineEntry {
        TimelineStorylineEntry(
            place: clip.place,
            id: clip.id,
            media: clip.source.media?.file,
            edit: clip.edit,
            drawn: clip.drawn,
            clip: clip.source.clipRange,
            speed: clip.source.speed,
            transition: clip.transition.map { TimelineTransition(preset: $0.preset, seconds: $0.seconds) },
            nested: clip.source.media?.nested.map { report(of: $0) }
        )
    }

    private func entry(
        of clip: ClipPlan,
        storyline: [StorylinePlan]
    ) -> TimelineClipEntry {
        let animation = clip.animation
        let parent = clip.isParented ? clip.storyline.map { storyline[$0].place } : nil

        return TimelineClipEntry(
            place: clip.place,
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
            nested: clip.media?.nested.map { report(of: $0) }
        )
    }

    private func span(_ span: PresetSpan) -> TimelineSpan {
        TimelineSpan(preset: span.preset, length: span.span.length)
    }
}
