//
//  ParentSpacePlanner.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Brings what a text form found for a clip under a shape or adjustment parent into that parent's space. The text is
// where it lies in the media searched at the value's instant, and the parent's transform carries the parent's space to
// that media, so the value is brought back through the transform of every shape or adjustment in the chain at that
// instant, each held at the edges of its own window as its evaluation holds it, the outermost first, without animation.
// A value written as numbers is in the parent's space already.
struct ParentSpacePlanner: Sendable {
    // MARK: - Property
    private let tracked: TrackPlan
    private let areas: [PropertyValue<FoundArea>?]

    // MARK: - Initializer
    // `areas` are what was found for each clip's area in the time plan's order, which say whether a track is a band's.
    init(
        tracked: TrackPlan,
        areas: [PropertyValue<FoundArea>?]
    ) {
        self.tracked = tracked
        self.areas = areas
    }

    // MARK: - Public
    func area(
        _ found: PropertyValue<FoundArea>?,
        written: PropertyValue<AreaForm>?,
        of plan: ClipPlan
    ) -> PropertyValue<FoundArea>? {
        guard let found, let written, let parent = plan.parent else { return found }

        return values(found, written: written, instant: plan.instant) { area, form, time in
            guard form.isFoundByText else { return area }

            let links = tracks(under: parent, at: time)
            return FoundArea(
                rectangle: links.reduce(area.rectangle) { rectangle, link in
                    link.track.bringBack(rectangle, fromMediaTime: link.mediaTime)
                },
                target: links.reduce(area.target) { rectangle, link in
                    link.track.bringBack(rectangle, fromMediaTime: link.mediaTime)
                },
                isBand: area.isBand,
                mediaTime: area.mediaTime,
                lines: area.lines
            )
        }
    }

    func position(
        _ found: PropertyValue<Point>?,
        written: PropertyValue<PositionForm>?,
        of plan: ClipPlan
    ) -> PropertyValue<Point>? {
        guard let found, let written, let parent = plan.parent else { return found }

        return values(found, written: written, instant: plan.instant) { point, form, time in
            guard form.isFoundByText else { return point }

            return tracks(under: parent, at: time).reduce(point) { point, link in
                link.track.bringBack(point: point, fromMediaTime: link.mediaTime)
            }
        }
    }

    // MARK: - Private
    // The tracks of the shapes and adjustments from the parent out to the clip whose media is searched, the outermost
    // first, each with the media time it is followed at, that of the instant its window holds. Only one parented to a
    // storyline clip is tracked, and the others in the chain have no transform of their own. ParentFinder has ruled out
    // a cycle, so the chain ends.
    private func tracks(
        under parent: ClipParent,
        at time: Double
    ) -> [(track: ResolvedTrack, mediaTime: Double)] {
        guard case let .clip(index, _) = parent else { return [] }

        let plan = tracked.time.clips[index]
        switch plan.kind {
        case .shape, .adjust:
            break

        default:
            return []
        }

        let outer = plan.parent.map { parent in tracks(under: parent, at: time) } ?? []
        guard let track = tracked.clips[index], case let .storyline(storyline, _) = plan.parent else { return outer }

        let mediaTime = tracked.time.storyline[storyline].mediaTime(atSequenceTime: plan.visible.held(time))
        return outer + [(ResolvedTrack(track: track, values: areas[index]), mediaTime)]
    }

    // A static value is found at the clip's instant and a keyframe at its own, both in sequence time, and the found
    // keyframes are in the order written.
    private func values<Form, Found>(
        _ found: PropertyValue<Found>,
        written: PropertyValue<Form>,
        instant: Double,
        bring: (Found, Form, Double) -> Found
    ) -> PropertyValue<Found> {
        switch (found, written) {
        case let (.value(value), .value(form)):
            return .value(bring(value, form, instant))

        case let (.keyframes(keyframes), .keyframes(forms)):
            return .keyframes(zip(keyframes, forms).map { keyframe, form in
                TimedValue(
                    index: keyframe.index,
                    at: keyframe.at,
                    value: bring(keyframe.value, form.value, keyframe.at),
                    ease: keyframe.ease
                )
            })

        default:
            return found
        }
    }
}
