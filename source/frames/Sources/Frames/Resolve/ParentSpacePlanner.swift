//
//  ParentSpacePlanner.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Brings what a text form found for a clip under a shape, adjustment or clip with a corner pin parent into that
// parent's space. The text is where it lies in the media searched at the time the value or its keyframe holds, and the
// chain of such parents from the parent out to that media carries the parent's space to it, so the value is brought
// back through the transform of each at that time, the outermost first, without animation, each held at the edges of
// its own window as its evaluation holds it: an adjustment's and a clip with a corner pin's tracked motion, and a
// shape's own scale and rotation about its anchor point and its position, then its tracked motion. A shape's own
// geometry and position are brought into its own parent's space the same way first. An area carried back through a
// rotation is the box bounding its four carried corners. A value written as numbers is in the parent's space already,
// and so is a clip area. A link with no inverse at that time, a scale of 0 on an axis, stops the clip, and so does a
// shape whose geometry or position holds a clip area, or a clip whose corner pin holds one, whose box or points only
// evaluation knows.
struct ParentSpacePlanner: Sendable {
    // MARK: - Property
    private let tracked: TrackPlan
    private let written: [Clip]
    private let shapes: [ShapeAppearance?]
    private let areas: [PropertyValue<AreaValue>?]
    private let points: [PropertyValue<[GeometryPoint]>?]
    private let positions: [PropertyValue<GeometryPoint>?]
    private let cornerPins: [PropertyValue<[GeometryPoint]>?]
    private let masks: [[FoundMask]?]
    // The transform of each shape placed by its geometry, nil for every other clip. Each is planned once, its
    // parents' first, since what a shape finds is brought back through its parents' transforms.
    private var transforms: [ParentTransformPlan?]

    // MARK: - Initializer
    // Each list is in the time plan's order of clips: the clips as written, their shapes as planned, and the areas,
    // points, positions, corner pins and masks found for them, in the media searched.
    init(
        tracked: TrackPlan,
        written: [Clip],
        shapes: [ShapeAppearance?],
        areas: [PropertyValue<AreaValue>?],
        points: [PropertyValue<[GeometryPoint]>?],
        positions: [PropertyValue<GeometryPoint>?],
        cornerPins: [PropertyValue<[GeometryPoint]>?],
        masks: [[FoundMask]?]
    ) throws {
        self.tracked = tracked
        self.written = written
        self.shapes = shapes
        self.areas = areas
        self.points = points
        self.positions = positions
        self.cornerPins = cornerPins
        self.masks = masks
        self.transforms = Array(repeating: nil, count: written.count)

        for index in written.indices.sorted(by: { depth(of: $0) < depth(of: $1) }) {
            transforms[index] = try transform(of: index)
        }
    }

    // MARK: - Public
    func area(of index: Int) throws -> PropertyValue<AreaValue>? {
        let plan = tracked.time.clips[index]
        guard let found = areas[index], let written = written[index].area, let parent = plan.parent else {
            return areas[index]
        }

        return try values(found, written: written, instant: plan.instant) { area, form, time in
            guard form.isFoundByText, let found = area.found else { return area }

            let inverses = try inverseLinks(under: parent, at: time, of: index, key: "area")
            return .found(FoundArea(
                rectangle: bringBack(found.rectangle, through: inverses),
                target: bringBack(found.target, through: inverses),
                mediaTime: found.mediaTime,
                lines: found.lines
            ))
        }
    }

    func points(of index: Int) throws -> PropertyValue<[GeometryPoint]>? {
        guard case let .shape(shape) = written[index].content else { return points[index] }

        return try points(points[index], written: shape.points, of: index, key: "points")
    }

    func cornerPin(of index: Int) throws -> PropertyValue<[GeometryPoint]>? {
        try points(cornerPins[index], written: written[index].cornerPin, of: index, key: "cornerPin")
    }

    func position(of index: Int) throws -> PropertyValue<GeometryPoint>? {
        let plan = tracked.time.clips[index]
        guard let found = positions[index], let written = written[index].position, let parent = plan.parent else {
            return positions[index]
        }

        return try values(found, written: written, instant: plan.instant) { point, form, time in
            guard form.isFoundByText else { return point }

            let inverses = try inverseLinks(under: parent, at: time, of: index, key: "position")
            return point.map { bringBack($0, through: inverses) }
        }
    }

    // The masks of a shape placed by its geometry or of an adjustment are in its parent's space, and each keyframe of
    // a mask's area, position or point found by text is brought back at its own time as an area, a position or a
    // point is. A box keeps its written size. Every other clip's mask is in its own space. A followed mask's geometry
    // leaf written without keyframes is true on the track's frame, but a leaf a text form found other than the track's
    // target.
    func mask(of index: Int) throws -> [ResolvedMask]? {
        let plan = tracked.time.clips[index]
        guard let found = masks[index] else { return nil }

        let isOnTrackFrame = plan.onTrackFrame(of: written[index]).contains(.mask)
        return try found.map { found in
            let mask = try broughtBack(found, of: index)
            guard isOnTrackFrame, let target = written[index].track else { return mask }

            return mask.onTrackFrame { leaf in
                found.staticLeaves.contains(leaf)
                    && target.isOnTrackFrame(.mask, isFoundByText: found.textTimes[leaf] != nil)
            }
        }
    }

    // MARK: - Private
    private func broughtBack(
        _ found: FoundMask,
        of index: Int
    ) throws -> ResolvedMask {
        let plan = tracked.time.clips[index]
        guard let parent = plan.parent, plan.space == .parent else { return found.mask }

        return try found.mask.carried(
            area: { area, time, leaf in
                guard let time, found.isFoundByText(leaf, at: time) else { return area }

                return bringBack(area, through: try inverseLinks(under: parent, at: time, of: index, key: "mask"))
            },
            point: { point, time, leaf in
                guard let time, found.isFoundByText(leaf, at: time) else { return point }

                return bringBack(point, through: try inverseLinks(under: parent, at: time, of: index, key: "mask"))
            },
            scale: { _ in 1 }
        )
    }

    // A list of points brought back point by point, those found by text.
    private func points(
        _ found: PropertyValue<[GeometryPoint]>?,
        written: PropertyValue<[PositionForm]>?,
        of index: Int,
        key: String
    ) throws -> PropertyValue<[GeometryPoint]>? {
        let plan = tracked.time.clips[index]
        guard let found, let written, let parent = plan.parent else { return found }

        return try values(found, written: written, instant: plan.instant) { points, forms, time in
            guard forms.contains(where: \.isFoundByText) else { return points }

            let inverses = try inverseLinks(under: parent, at: time, of: index, key: key)
            return zip(points, forms).map { point, form in
                form.isFoundByText ? point.map { bringBack($0, through: inverses) } : point
            }
        }
    }

    // The map of each shape, adjustment and clip with a corner pin from the parent out to the clip whose media is
    // searched, the outermost first, each from the space its children are written in to that of its own parent at the
    // time its window holds: a clip with a corner pin carries its children by its tracked motion only (FRAMES-10). Only
    // one parented to a clip with video is tracked, a shape given by `width` and `height` has a space with no picture to
    // search, and ParentFinder has ruled out a cycle, so the chain ends.
    private func links(
        under parent: ClipParent,
        at time: Double,
        of child: Int,
        key: String
    ) throws -> [AffineTransform] {
        var links: [AffineTransform] = []
        var next: ClipParent? = parent
        while case let .clip(index, _) = next {
            let plan = tracked.time.clips[index]
            switch plan.kind {
            case _ where plan.isPinned, .shape where transforms[index] != nil, .adjust:
                break

            default:
                return links.reversed()
            }

            let holdsClipArea = plan.isPinned
                ? cornerPins[index]?.keyframes(at: plan.instant) { $0 }.contains { $0.value.contains { $0.clipArea != nil } } == true
                : transforms[index]?.geometry.holdsClipArea == true
            if holdsClipArea {
                throw ResolveError.textUnderClipArea(
                    place: written[child].place.appending(key: key),
                    kind: .clip(tracked.time.clips[child].kind),
                    parent: plan.id ?? plan.place.description
                )
            }

            let held = plan.visible.held(time)
            let own = transforms[index]?.transform(at: held) ?? .identity
            if let track = tracked.clips[index] {
                links.append(own.concatenating(track.motion(at: held).transform))
            } else {
                links.append(own)
            }
            next = plan.parent
        }

        return links.reversed()
    }

    // How many parents a clip has above it. ParentFinder has ruled out a cycle, so the chain ends.
    private func depth(of index: Int) -> Int {
        var depth = 0
        var next = tracked.time.clips[index].parent
        while case let .clip(parent, _) = next {
            depth += 1
            next = tracked.time.clips[parent].parent
        }

        return depth
    }

    // A shape placed by its geometry as its transform needs it: its geometry made from its plan and its area or
    // points and position as found, as its entry makes it. A shape given by `width` and `height` and an adjustment
    // have no such transform.
    private func transform(of index: Int) throws -> ParentTransformPlan? {
        guard let shape = shapes[index] else { return nil }
        if case .box = shape.geometry { return nil }

        let plan = tracked.time.clips[index]
        let written = written[index]
        let track = tracked.clips[index]
        let onTrackFrame = plan.onTrackFrame(of: written)
        return ParentTransformPlan(
            geometry: ShapeGeometry(
                plan: shape.geometry,
                area: try area(of: index)?
                    .followed(at: plan.instant, isOnTrackFrame: onTrackFrame.contains(.area)) { $0.geometry },
                points: try points(of: index)?
                    .followed(at: plan.instant, isOnTrackFrame: onTrackFrame.contains(.points)) { $0 },
                position: try position(of: index)?
                    .followed(at: plan.instant, isOnTrackFrame: onTrackFrame.contains(.position)) { $0 },
                instant: plan.instant,
                track: track
            ),
            track: track,
            scale: (written.scale?.inSequenceTime(on: plan.clock) ?? .value(.identity)).keyframes(at: plan.instant) { $0 },
            rotation: (written.rotation?.inSequenceTime(on: plan.clock) ?? .value(0)).keyframes(at: plan.instant) { $0 }
        )
    }

    // The inverse of each link under `parent` at `time`, in the order `links(under:at:)` gives them.
    private func inverseLinks(
        under parent: ClipParent,
        at time: Double,
        of index: Int,
        key: String
    ) throws -> [AffineTransform] {
        try links(under: parent, at: time, of: index, key: key).map { link in
            guard let inverse = link.inverse else {
                throw ResolveError.flatParent(
                    place: written[index].place.appending(key: key),
                    kind: .clip(tracked.time.clips[index].kind),
                    instant: time
                )
            }

            return inverse
        }
    }

    private func bringBack(
        _ point: Point,
        through inverses: [AffineTransform]
    ) -> Point {
        inverses.reduce(point) { point, inverse in inverse.apply(to: point) }
    }

    private func bringBack(
        _ rectangle: Rectangle,
        through inverses: [AffineTransform]
    ) -> Rectangle {
        inverses.reduce(rectangle) { rectangle, inverse in Rectangle(bounding: inverse.apply(toCornersOf: rectangle)) }
    }

    // A static value is found at the clip's instant and a keyframe at its own, both in sequence time, and the found
    // keyframes are in the order written.
    private func values<Form, Found>(
        _ found: PropertyValue<Found>,
        written: PropertyValue<Form>,
        instant: Double,
        bring: (Found, Form, Double) throws -> Found
    ) throws -> PropertyValue<Found> {
        switch (found, written) {
        case let (.value(value), .value(form)):
            return .value(try bring(value, form, instant))

        case let (.keyframes(keyframes), .keyframes(forms)):
            return .keyframes(try zip(keyframes, forms).map { keyframe, form in
                PropertyKeyframe(
                    index: keyframe.index,
                    at: keyframe.at,
                    value: try bring(keyframe.value, form.value, keyframe.at),
                    ease: keyframe.ease
                )
            })

        default:
            return found
        }
    }
}
