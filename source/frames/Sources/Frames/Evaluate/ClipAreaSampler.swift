//
//  ClipAreaSampler.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The clip areas `clip` writes, at an instant, in the space `clip` is drawn in. The named clip's box is taken before
// its own transform and tracked motion, at the instant held to its window; a title's is its text box with its
// background at that instant. With the same parent or none, a box of its own keeps its size in output pixels, so its
// anchor point is carried out to output pixels by the parent's map and the box drawn there is carried back by the
// map's inverse, bounded where the map turns, and the padding is divided by the map's length factor; a shape placed by
// its geometry gives its geometry's box. Named as the parent, it is its box in the space it gives its children. Resolve
// has checked that every id names a clip that may be named and that no cycle holds, so the walk through clip areas the
// named clip writes ends. A clip with a corner pin gives its corner pin bounds, its padding not divided by a length factor.
struct ClipAreaSampler: Sendable {
    // MARK: - Property
    private let sequence: ResolvedSequence
    private let clip: ResolvedClip

    // MARK: - Initializer
    init(
        sequence: ResolvedSequence,
        clip: ResolvedClip
    ) {
        self.sequence = sequence
        self.clip = clip
    }

    // MARK: - Public
    func rectangle(
        of area: GeometryArea,
        at time: Double
    ) -> Rectangle {
        switch area {
        case let .rectangle(rectangle):
            rectangle

        case let .clip(area):
            rectangle(of: area, at: time)
        }
    }

    func point(
        of point: GeometryPoint,
        at time: Double
    ) -> Point {
        switch point {
        case let .point(point):
            return point

        case let .clip(area, name):
            return rectangle(of: area, at: time).point(named: name)
        }
    }

    // Each keyframe at `time`, a clip area in it the named clip's box at `time`, so a span next to one moves with it.
    func rectangles(
        of keyframes: [Keyframe<GeometryArea>],
        at time: Double
    ) -> [Keyframe<Rectangle>] {
        keyframes.map { $0.map { rectangle(of: $0, at: time) } }
    }

    func points(
        of keyframes: [Keyframe<GeometryPoint>],
        at time: Double
    ) -> [Keyframe<Point>] {
        keyframes.map { $0.map { point(of: $0, at: time) } }
    }

    func points(
        of keyframes: [Keyframe<[GeometryPoint]>],
        at time: Double
    ) -> [Keyframe<[Point]>] {
        keyframes.map { $0.map { points in points.map { point(of: $0, at: time) } } }
    }

    // MARK: - Private
    private func rectangle(
        of area: ClipArea,
        at time: Double
    ) -> Rectangle {
        guard let named = sequence.clips.first(where: { $0.id == area.clip }) else {
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }

        let held = TimeRange(start: named.start, end: named.end).held(time)
        if named.cornerPin != nil {
            return cornerPinBounds(of: named, at: held).grown(by: area.padding)
        }
        if clip.parent == named.id {
            return childBox(of: named, at: held).grown(by: area.padding)
        }

        let space = ParentEvaluator(sequence: sequence).space(of: named, at: held)
        let length = space.transform.lengthFactor
        return box(of: named, in: space, at: held).grown(by: length > 0 ? area.padding / length : 0)
    }

    // A clip with a corner pin gives its corner pin bounds, in the space its corner pin is written in, to a sibling
    // and a child alike, before its tracked motion (FRAMES-27 The key).
    private func cornerPinBounds(
        of named: ResolvedClip,
        at time: Double
    ) -> Rectangle {
        let clock = named.parentTrack == nil ? nil : ParentEvaluator(sequence: sequence).space(of: named, at: time).clock
        let areas = ClipAreaSampler(sequence: sequence, clip: named)
        return named.cornerPinBounds(areas: areas, clock: clock, at: time) ?? Rectangle(x: 0, y: 0, width: 0, height: 0)
    }

    // The named clip's box in the space it is drawn in.
    private func box(
        of named: ResolvedClip,
        in space: ClipSpace,
        at time: Double
    ) -> Rectangle {
        if case let .shape(shape) = named.content, let geometry = geometryBox(of: shape, writtenBy: named, at: time) {
            return geometry
        }
        guard let box = named.box else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }

        let extent = self.extent(of: named, box: box, at: time)
        let carried = space.transform.apply(to: space.anchor(of: box, track: nil, at: time))
        let drawn = Rectangle(
            x: carried.x + extent.x,
            y: carried.y + extent.y,
            width: extent.width,
            height: extent.height
        )
        guard let inverse = space.transform.inverse else { return drawn }

        return Rectangle(bounding: inverse.apply(toCornersOf: drawn))
    }

    // The named parent's box in the space it gives its children.
    private func childBox(
        of named: ResolvedClip,
        at time: Double
    ) -> Rectangle {
        if case let .shape(shape) = named.content, let geometry = geometryBox(of: shape, writtenBy: named, at: time) {
            return geometry
        }
        guard let box = named.box else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }
        if case .media = named.content, let crop = named.crop(at: time) {
            return crop
        }

        let extent = self.extent(of: named, box: box, at: time)
        return Rectangle(x: 0, y: 0, width: extent.width, height: extent.height)
    }

    // A shape placed by its geometry's area or the box bounding its points, nil for one placed by its box.
    private func geometryBox(
        of shape: ResolvedShape,
        writtenBy named: ResolvedClip,
        at time: Double
    ) -> Rectangle? {
        let sampler = ClipAreaSampler(sequence: sequence, clip: named)
        switch shape.geometry {
        case .box:
            return nil

        case let .area(area, _, _):
            return sampler.rectangles(of: area, at: time).value(at: time)

        case let .points(points, _, _):
            return Rectangle(bounding: sampler.points(of: points, at: time).value(at: time))
        }
    }

    // The named clip's box at a time in its own pixels, with its anchor point at the origin: a box shape's `width` and
    // `height`, its anchor at the same fraction of them; a title's box at the time, about the anchor point resolve
    // placed, which stays while the box changes; and any other clip's box.
    private func extent(
        of named: ResolvedClip,
        box: ResolvedBox,
        at time: Double
    ) -> Rectangle {
        switch named.content {
        case let .shape(shape):
            guard case let .box(width, height, _) = shape.geometry else { return extent(of: box) }

            let size = Size(width: width.value(at: time), height: height.value(at: time))
            return Rectangle(
                x: box.size.width > 0 ? -box.anchor.x * size.width / box.size.width : 0,
                y: box.size.height > 0 ? -box.anchor.y * size.height / box.size.height : 0,
                width: size.width,
                height: size.height
            )

        case let .title(text):
            let drawn = text.box(at: time)
            return Rectangle(
                x: drawn.x - box.anchor.x,
                y: drawn.y - box.anchor.y,
                width: drawn.width,
                height: drawn.height
            )

        case .media, .adjustment:
            return extent(of: box)
        }
    }

    private func extent(of box: ResolvedBox) -> Rectangle {
        Rectangle(x: -box.anchor.x, y: -box.anchor.y, width: box.size.width, height: box.size.height)
    }
}
