//
//  ParentSpacePlanner.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Brings what a text form found for a clip under a shape or adjustment parent into that parent's space (FRAMES-2). The
// text is where it lies in the media searched at the value's instant, and the chain of shapes and adjustments from the
// parent out to that media carries the parent's space to it, so the value is brought back through the transform of
// each at that instant, the outermost first, without animation, each held at the edges of its own window as its
// evaluation holds it: an adjustment's tracked motion, and a shape's own scale and rotation about its anchor point and
// its position, then its tracked motion. A shape's own geometry and position are brought into its own parent's space
// the same way first. An area carried back through a rotation is the box bounding its four carried corners. A value
// written as numbers is in the parent's space already. A space at scale 0 is flattened to a point, so a value is left
// as it is where a link cannot be undone.
struct ParentSpacePlanner: Sendable {
    // MARK: - Property
    private let tracked: TrackPlan
    private let written: [Clip]
    private let shapes: [ShapeAppearance?]
    private let areas: [PropertyValue<FoundArea>?]
    private let points: [PropertyValue<[Point]>?]
    private let positions: [PropertyValue<Point>?]

    // MARK: - Initializer
    // Each list is in the time plan's order of clips: the clips as written, their shapes as planned, and the areas,
    // points and positions found for them, in the media searched.
    init(
        tracked: TrackPlan,
        written: [Clip],
        shapes: [ShapeAppearance?],
        areas: [PropertyValue<FoundArea>?],
        points: [PropertyValue<[Point]>?],
        positions: [PropertyValue<Point>?]
    ) {
        self.tracked = tracked
        self.written = written
        self.shapes = shapes
        self.areas = areas
        self.points = points
        self.positions = positions
    }

    // MARK: - Public
    func area(of index: Int) -> PropertyValue<FoundArea>? {
        let plan = tracked.time.clips[index]
        guard let found = areas[index], let written = written[index].area, let parent = plan.parent else {
            return areas[index]
        }

        return values(found, written: written, instant: plan.instant) { area, form, time in
            guard form.isFoundByText else { return area }

            let links = links(under: parent, at: time)
            return FoundArea(
                rectangle: bringBack(area.rectangle, through: links),
                target: bringBack(area.target, through: links),
                mediaTime: area.mediaTime,
                lines: area.lines
            )
        }
    }

    func points(of index: Int) -> PropertyValue<[Point]>? {
        let plan = tracked.time.clips[index]
        guard let found = points[index],
            case let .shape(shape) = written[index].content,
            let written = shape.points,
            let parent = plan.parent
        else { return points[index] }

        return values(found, written: written, instant: plan.instant) { points, forms, time in
            guard forms.contains(where: \.isFoundByText) else { return points }

            let links = links(under: parent, at: time)
            return zip(points, forms).map { point, form in
                form.isFoundByText ? bringBack(point, through: links) : point
            }
        }
    }

    func position(of index: Int) -> PropertyValue<Point>? {
        let plan = tracked.time.clips[index]
        guard let found = positions[index], let written = written[index].position, let parent = plan.parent else {
            return positions[index]
        }

        return values(found, written: written, instant: plan.instant) { point, form, time in
            guard form.isFoundByText else { return point }

            return bringBack(point, through: links(under: parent, at: time))
        }
    }

    // MARK: - Private
    // The map of each shape and adjustment from the parent out to the clip whose media is searched, the outermost
    // first, each from the space its children are written in to that of its own parent at the time its window holds.
    // Only one parented to a storyline clip is tracked, a shape given by `width` and `height` has a space with no
    // picture to search, and ParentFinder has ruled out a cycle, so the chain ends.
    private func links(
        under parent: ClipParent,
        at time: Double
    ) -> [AffineTransform] {
        guard case let .clip(index, _) = parent else { return [] }

        let plan = tracked.time.clips[index]
        switch plan.kind {
        case .shape where shapes[index]?.width == nil, .adjust:
            break

        default:
            return []
        }

        let held = plan.visible.held(time)
        let outer = plan.parent.map { parent in links(under: parent, at: time) } ?? []
        let own = transform(of: index)?.transform(at: held) ?? .identity
        guard let link = track(of: index) else { return outer + [own] }

        let mediaTime = tracked.time.storyline[link.storyline].mediaTime(atSequenceTime: held)
        return outer + [own.concatenating(AffineTransform(carrying: link.track.track.motion(atMediaTime: mediaTime)))]
    }

    // A shape placed by its geometry as its transform needs it, its area grown by its outset and its named anchor
    // taken on its geometry's box at its instant, as its entry has them (`ResolvedShape(shape:geometry:instant:)`). An
    // adjustment has no transform of its own.
    private func transform(of index: Int) -> ParentTransformPlan? {
        guard let shape = shapes[index] else { return nil }

        let plan = tracked.time.clips[index]
        let area = atInstant(
            area(of: index)?.keyframes(at: plan.instant) { $0.rectangle.grown(by: shape.outset) },
            of: index
        ) { track, rectangle, mediaTime in
            track.bringBack(rectangle, fromMediaTime: mediaTime)
        }
        let points = atInstant(
            points(of: index)?.keyframes(at: plan.instant) { $0 },
            of: index
        ) { track, points, time in
            points.map { track.bringBack($0, fromMediaTime: time) }
        }
        let position = atInstant(
            position(of: index)?.keyframes(at: plan.instant) { $0 },
            of: index
        ) { track, point, time in
            track.bringBack(point, fromMediaTime: time)
        }
        let box = area.map { $0.value(at: plan.instant) }
            ?? points.map { Rectangle(bounding: $0.value(at: plan.instant)) }
        let written = written[index]

        return ParentTransformPlan(
            area: area,
            points: points,
            position: position,
            anchor: shape.anchor.flatMap { name in box?.point(named: name) },
            scale: (written.scale?.inSequenceTime(on: plan.clock) ?? .value(1)).keyframes(at: plan.instant) { $0 },
            rotation: (written.rotation?.inSequenceTime(on: plan.clock) ?? .value(0)).keyframes(at: plan.instant) { $0 }
        )
    }

    // A tracked clip's keyframes each brought back through the motion at the media time of its `at`, to where it lies
    // at the instant, as its evaluation brings them back.
    private func atInstant<Value: Interpolable>(
        _ keyframes: [Keyframe<Value>]?,
        of index: Int,
        bringBack: (ResolvedTrack, Value, Double) -> Value
    ) -> [Keyframe<Value>]? {
        guard let keyframes, let link = track(of: index) else { return keyframes }

        return keyframes.map { keyframe in
            let mediaTime = tracked.time.storyline[link.storyline].mediaTime(atSequenceTime: keyframe.at)
            let value = bringBack(link.track, keyframe.value, mediaTime)
            return Keyframe(at: keyframe.at, value: value, ease: keyframe.ease)
        }
    }

    // The track a clip parented to a storyline clip follows, and the index of that storyline clip.
    private func track(of index: Int) -> (track: ResolvedTrack, storyline: Int)? {
        guard let track = tracked.clips[index],
            case let .storyline(storyline, _) = tracked.time.clips[index].parent
        else { return nil }

        return (ResolvedTrack(track: track), storyline)
    }

    private func bringBack(
        _ point: Point,
        through links: [AffineTransform]
    ) -> Point {
        links.reduce(point) { point, link in link.inverse?.apply(to: point) ?? point }
    }

    private func bringBack(
        _ rectangle: Rectangle,
        through links: [AffineTransform]
    ) -> Rectangle {
        links.reduce(rectangle) { rectangle, link in
            link.inverse.map { Rectangle(bounding: $0.apply(toCornersOf: rectangle)) } ?? rectangle
        }
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
