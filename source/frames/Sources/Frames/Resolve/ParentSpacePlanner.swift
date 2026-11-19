//
//  ParentSpacePlanner.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// Brings what a text form found for a clip under a shape or adjustment parent into that parent's space. The text is
// where it lies in the media searched at the value's instant, and the chain of shapes and adjustments from the parent
// out to that media carries the parent's space to it, so the value is brought back through the transform of each at
// that instant, the outermost first, without animation, each held at the edges of its own window as its evaluation
// holds it: an adjustment's tracked motion, and a shape's own scale and rotation about its anchor point and its
// position, then its tracked motion. A shape's own geometry and position are brought into its own parent's space the
// same way first. An area carried back through a rotation is the box bounding its four carried corners. A value written
// as numbers is in the parent's space already. A space at scale 0 is flattened to a point, so a value is left as it is
// where a link cannot be undone.
struct ParentSpacePlanner: Sendable {
    // MARK: - Property
    private let tracked: TrackPlan
    private let written: [Clip]
    private let shapes: [ShapeAppearance?]
    private let areas: [PropertyValue<FoundArea>?]
    private let points: [PropertyValue<[Point]>?]
    private let positions: [PropertyValue<Point>?]
    private let masks: [PropertyValue<[ResolvedMask]>?]
    // The transform of each shape placed by its geometry, nil for every other clip. Each is planned once, its
    // parents' first, since what a shape finds is brought back through its parents' transforms.
    private var transforms: [ParentTransformPlan?]

    // MARK: - Initializer
    // Each list is in the time plan's order of clips: the clips as written, their shapes as planned, and the areas,
    // points, positions and masks found for them, in the media searched.
    init(
        tracked: TrackPlan,
        written: [Clip],
        shapes: [ShapeAppearance?],
        areas: [PropertyValue<FoundArea>?],
        points: [PropertyValue<[Point]>?],
        positions: [PropertyValue<Point>?],
        masks: [PropertyValue<[ResolvedMask]>?]
    ) {
        self.tracked = tracked
        self.written = written
        self.shapes = shapes
        self.areas = areas
        self.points = points
        self.positions = positions
        self.masks = masks
        self.transforms = Array(repeating: nil, count: written.count)

        for index in written.indices.sorted(by: { depth(of: $0) < depth(of: $1) }) {
            transforms[index] = transform(of: index)
        }
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

    // The masks of a shape placed by its geometry or of an adjustment are in its parent's space, and each mask's area,
    // position or points found by text is brought back as an area, a position or points are. A box is moved by its
    // brought-back centre and keeps its written size. Every other clip's mask is in its own space.
    func mask(of index: Int) -> PropertyValue<[ResolvedMask]>? {
        let plan = tracked.time.clips[index]
        guard
            let found = masks[index],
            let written = written[index].mask,
            let parent = plan.parent,
            plan.space == .parent
        else {
            return masks[index]
        }

        return values(found, written: written, instant: plan.instant) { masks, forms, time in
            guard forms.contains(where: \.geometry.isFoundByText) else { return masks }

            let links = links(under: parent, at: time)
            return zip(masks, forms).map { mask, form in
                mask.replacing(geometry: bringBack(mask.geometry, written: form.geometry, through: links))
            }
        }
    }

    // MARK: - Private
    private func bringBack(
        _ geometry: PathGeometry,
        written: MaskGeometryForm,
        through links: [AffineTransform]
    ) -> PathGeometry {
        guard written.isFoundByText else { return geometry }

        switch (geometry, written) {
        case let (.rect(rectangle, radius), .area):
            return .rect(bringBack(rectangle, through: links), radius: radius)

        case let (.ellipse(rectangle), .area):
            return .ellipse(bringBack(rectangle, through: links))

        case let (.rect(rectangle, radius), .box):
            return .rect(moved(rectangle, through: links), radius: radius)

        case let (.ellipse(rectangle), .box):
            return .ellipse(moved(rectangle, through: links))

        case let (.polyline(points, isClosed), .points(forms)):
            let brought = zip(points, forms).map { point, form in
                form.isFoundByText ? bringBack(point, through: links) : point
            }
            return .polyline(brought, isClosed: isClosed)

        default:
            return geometry
        }
    }

    // A box keeps its size and is centred on its centre brought back.
    private func moved(
        _ rectangle: Rectangle,
        through links: [AffineTransform]
    ) -> Rectangle {
        Rectangle(center: bringBack(rectangle.center, through: links), width: rectangle.width, height: rectangle.height)
    }

    // The map of each shape and adjustment from the parent out to the clip whose media is searched, the outermost
    // first, each from the space its children are written in to that of its own parent at the time its window holds.
    // Only one parented to a clip with video is tracked, a shape given by `width` and `height` has a space with no
    // picture to search, and ParentFinder has ruled out a cycle, so the chain ends.
    private func links(
        under parent: ClipParent,
        at time: Double
    ) -> [AffineTransform] {
        var links: [AffineTransform] = []
        var next: ClipParent? = parent
        while case let .clip(index, _) = next {
            let plan = tracked.time.clips[index]
            switch plan.kind {
            case .shape where transforms[index] != nil, .adjust:
                break

            default:
                return links.reversed()
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
    private func transform(of index: Int) -> ParentTransformPlan? {
        guard let shape = shapes[index] else { return nil }
        if case .box = shape.geometry { return nil }

        let plan = tracked.time.clips[index]
        let written = written[index]
        let track = tracked.clips[index]
        return ParentTransformPlan(
            geometry: ShapeGeometry(
                plan: shape.geometry,
                area: area(of: index)?.keyframes(at: plan.instant) { $0.rectangle },
                points: points(of: index)?.keyframes(at: plan.instant) { $0 },
                position: position(of: index)?.keyframes(at: plan.instant) { $0 },
                instant: plan.instant,
                track: track
            ),
            track: track,
            scale: (written.scale?.inSequenceTime(on: plan.clock) ?? .value(.identity)).keyframes(at: plan.instant) { $0 },
            rotation: (written.rotation?.inSequenceTime(on: plan.clock) ?? .value(0)).keyframes(at: plan.instant) { $0 }
        )
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
                PropertyKeyframe(
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
