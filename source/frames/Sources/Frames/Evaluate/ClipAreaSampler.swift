//
//  ClipAreaSampler.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The clip areas `clip` writes, at an instant, in the space `clip` is drawn in. The named clip's box is taken before
// its own transform and tracked motion, at the instant held to its window, and under motion blur at its own value time
// by its own switch (FRAMES-29); a title's is its text box with its background at that instant. With the same parent or
// none, a box of its own keeps its size in output pixels, so its anchor point is carried out to output pixels by the
// parent's map and the box drawn there is carried back by the map's inverse, bounded where the map turns, and the
// padding is divided by the map's length factor; a shape placed by its geometry gives its geometry's box. Named as the
// parent, it is its box in the space it gives its children. Resolve has checked that every id names a clip that may be
// named and that no cycle holds, so the walk through clip areas the named clip writes ends. A clip with a corner pin
// gives its corner pin bounds, its padding not divided by a length factor. A storyline clip, which only an unparented
// clip or a child of it names, gives its box in output pixels or its crop in its media pixels.
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
        at time: SampleTime
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
        at time: SampleTime
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
        of keyframes: FollowedValue<GeometryArea>,
        at time: SampleTime
    ) -> FollowedValue<Rectangle> {
        keyframes.mapValues { rectangle(of: $0, at: time) }
    }

    func points(
        of keyframes: FollowedValue<GeometryPoint>,
        at time: SampleTime
    ) -> FollowedValue<Point> {
        keyframes.mapValues { point(of: $0, at: time) }
    }

    func quads(
        of keyframes: FollowedValue<GeometryQuad>,
        at time: SampleTime
    ) -> FollowedValue<Quad> {
        keyframes.mapValues { quad in quad.sampled { point(of: $0, at: time) } }
    }

    // MARK: - Private
    private func rectangle(
        of area: ClipArea,
        at time: SampleTime
    ) -> Rectangle {
        if let index = sequence.storyline.firstIndex(where: { $0.id == area.clip }) {
            return storylineBox(of: index, at: time).grown(by: area.padding)
        }
        guard let named = sequence.clips.first(where: { $0.id == area.clip }) else {
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }

        let held = named.valueTime(in: time.sample)
        if case let .picture(_, .cornerPin(cornerPin), _) = named.content {
            return cornerPinBounds(of: named, cornerPin: cornerPin, at: held).grown(by: area.padding)
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
        cornerPin: ResolvedCornerPin,
        at time: SampleTime
    ) -> Rectangle {
        let clock = named.parentTrack == nil ? nil : ParentEvaluator(sequence: sequence).space(of: named, at: time).clock
        let areas = ClipAreaSampler(sequence: sequence, clip: named)
        return named.cornerPinBounds(cornerPin, areas: areas, clock: clock, at: time)
    }

    // A storyline clip's box at the instant held to its drawn range, its transitions included, before its own `scale`,
    // `rotation` and transition motion, as any named clip's box is taken before its own transform and animation: its
    // corner pin bounds where it has one, in output pixels, which it gives its children too; to a child, its crop in its
    // media pixels, the space it gives the child; and to an unparented clip, the frame its crop fills with its anchor
    // point at its position, in output pixels. A solid, which no clip area names, gives an empty box.
    private func storylineBox(
        of index: Int,
        at time: SampleTime
    ) -> Rectangle {
        let storyline = sequence.storyline
        let entry = storyline[index]
        let held = storyline.valueTime(ofEntry: index, in: time.sample)
        if let cornerPin = entry.cornerPin(at: held) {
            return Rectangle(bounding: cornerPin.corners)
        }
        if clip.parent == entry.id {
            return entry.crop(at: held)
        }
        guard case .media = entry.content, case let .transform(box, _, _) = entry.picture.placement else {
            return Rectangle(x: 0, y: 0, width: 0, height: 0)
        }

        let anchor = box.position.mapValues(\.fixed).value(at: held)
        return Rectangle(
            x: anchor.x - box.anchor.x,
            y: anchor.y - box.anchor.y,
            width: box.size.width,
            height: box.size.height
        )
    }

    // The named clip's box in the space it is drawn in.
    private func box(
        of named: ResolvedClip,
        in space: ClipSpace,
        at time: SampleTime
    ) -> Rectangle {
        if let shape = geometry(of: named), let geometry = geometryBox(of: shape, writtenBy: named, at: time) {
            return geometry
        }
        guard let box = placedBox(of: named) else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }

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
        at time: SampleTime
    ) -> Rectangle {
        if let shape = geometry(of: named), let geometry = geometryBox(of: shape, writtenBy: named, at: time) {
            return geometry
        }
        guard let box = placedBox(of: named) else { return Rectangle(x: 0, y: 0, width: 0, height: 0) }
        if case let .picture(.media(media), _, _) = named.content {
            return named.crop(of: media, at: time)
        }

        let extent = self.extent(of: named, box: box, at: time)
        return Rectangle(x: 0, y: 0, width: extent.width, height: extent.height)
    }

    // The box the named clip is placed by, which a title, a media clip, a shape and a null take from their transform and
    // an adjustment holds alone. Nil for a shape or a null placed by its geometry, an adjustment over the whole frame, and
    // a clip a corner pin places, whose corner pin bounds are taken before.
    private func placedBox(of named: ResolvedClip) -> ResolvedBox? {
        switch named.content {
        case let .picture(_, .transform(transform), _):
            transform.box

        case .picture(_, .cornerPin, _):
            nil

        case let .adjustment(_, box, _):
            box

        case let .null(null):
            null.transform.box
        }
    }

    // The geometry of a shape, or of a null, whose box is a rect's given the same way, nil for any other clip.
    private func geometry(of named: ResolvedClip) -> ShapeGeometry? {
        switch named.content {
        case let .picture(.shape(shape), _, _):
            shape.geometry

        case let .null(null):
            null.geometry.shape

        case .picture(.title, _, _), .picture(.media, _, _), .adjustment:
            nil
        }
    }

    // A shape placed by its geometry's area or the box of its path's curve (FRAMES-11 Shapes), nil for one placed by its
    // box.
    private func geometryBox(
        of geometry: ShapeGeometry,
        writtenBy named: ResolvedClip,
        at time: SampleTime
    ) -> Rectangle? {
        let sampler = ClipAreaSampler(sequence: sequence, clip: named)
        switch geometry {
        case .box:
            return nil

        case let .area(area, _, _):
            return sampler.rectangles(of: area, at: time).value(at: time)

        case let .points(vertices, isClosed, _):
            return vertices
                .map { vertex in
                    vertex.map(
                        vertex: { sampler.points(of: $0, at: time).value(at: time) },
                        tangent: { $0.value(at: time) }
                    )
                }
                .bounds(isClosed: isClosed)
        }
    }

    // The named clip's box at a time in its own pixels, with its anchor point at the origin: a box shape's or a box
    // null's `width` and `height`, its anchor at the same fraction of them; a title's box at the time, about the anchor point resolve
    // placed, which stays while the box changes; and any other clip's box.
    private func extent(
        of named: ResolvedClip,
        box: ResolvedBox,
        at time: SampleTime
    ) -> Rectangle {
        switch named.content {
        case .picture(.shape, _, _), .null:
            guard case let .box(width, height, _) = geometry(of: named) else { return extent(of: box) }

            let size = Size(width: width.value(at: time), height: height.value(at: time))
            return Rectangle(
                x: box.size.width > 0 ? -box.anchor.x * size.width / box.size.width : 0,
                y: box.size.height > 0 ? -box.anchor.y * size.height / box.size.height : 0,
                width: size.width,
                height: size.height
            )

        case let .picture(.title(text), _, _):
            let drawn = text.box(at: time)
            return Rectangle(
                x: drawn.x - box.anchor.x,
                y: drawn.y - box.anchor.y,
                width: drawn.width,
                height: drawn.height
            )

        case .picture(.media, _, _), .adjustment:
            return extent(of: box)
        }
    }

    private func extent(of box: ResolvedBox) -> Rectangle {
        Rectangle(x: -box.anchor.x, y: -box.anchor.y, width: box.size.width, height: box.size.height)
    }
}
