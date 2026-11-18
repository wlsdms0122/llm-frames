//
//  ContentFitPlanner.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

import Foundation

// Measures a content-fit frame from a sequence planned in its measuring space, and moves what is written in that
// space onto the measured frame. Each clip's extent is its geometry at sequence time 0 without animation or transition
// motion, its parent's included, as evaluation carries it: a storyline picture's or media clip's box, a title's text
// box, and a shape's outline grown by half its stroke width, with its arrowheads. A solid fills the frame and an
// adjustment applies to it, so neither is measured. The union is rounded outward to whole pixels, the margin is added,
// and each side is rounded up to an even number.
struct ContentFitPlanner: Sendable {
    // MARK: - Property
    private let clipEvaluator = ClipEvaluator()
    private let shapeEvaluator = ShapeEvaluator()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `plan` is planned on a frame the size of its first storyline picture's box, and its storyline has a picture.
    // `inOutputPixels` says for each clip whether its coordinates are output pixels, which under content fit are the
    // measuring space, so the clip moves with the content.
    func fitted(
        _ plan: SequencePlan,
        margin: Margin,
        inOutputPixels: [Bool]
    ) throws -> SequencePlan {
        let still = try self.still(ResolvedSequence(plan: plan, hashes: PlaceholderHasher()))
        guard let union = extents(of: still).reduce(nil, { union, extent in union?.union(extent) ?? extent }) else {
            throw ResolveError.contentFitWithoutPicture(
                place: plan.time.sequence.place.appending(key: "format").appending(key: "size"),
                kind: .sequence
            )
        }

        let x0 = floor(union.x)
        let y0 = floor(union.y)
        let width = ceil(union.maxX) - x0 + margin.left + margin.right
        let height = ceil(union.maxY) - y0 + margin.top + margin.bottom
        let size = Size(width: (width / 2).rounded(.up) * 2, height: (height / 2).rounded(.up) * 2)
        let offset = Point(x: margin.left - x0, y: margin.top - y0)
        let format = FormatPlan(
            size: size,
            conform: plan.format.conform,
            background: plan.format.background,
            fps: plan.format.fps,
            duration: plan.format.duration,
            margin: margin
        )

        return SequencePlan(
            time: plan.time,
            format: format,
            storyline: plan.storyline.map { moved($0, by: offset) },
            clips: plan.clips.indices.map { index in
                inOutputPixels[index] ? moved(plan.clips[index], by: offset) : plan.clips[index]
            },
            sound: plan.sound
        )
    }

    // MARK: - Private
    // The sequence as `geometry(clip, t)` sees it: no clip animates and no storyline clip transitions.
    private func still(_ sequence: ResolvedSequence) -> ResolvedSequence {
        ResolvedSequence(
            format: sequence.format,
            storyline: sequence.storyline.map { entry in
                ResolvedStorylineClip(
                    place: entry.place,
                    id: entry.id,
                    media: entry.media,
                    solid: entry.solid,
                    in: entry.in,
                    out: entry.out,
                    speed: entry.speed,
                    start: entry.start,
                    end: entry.end,
                    crop: entry.crop,
                    track: entry.track,
                    filter: entry.filter,
                    box: entry.box,
                    opacity: entry.opacity,
                    scale: entry.scale,
                    rotation: entry.rotation,
                    blend: entry.blend,
                    radius: entry.radius,
                    border: entry.border,
                    shadow: entry.shadow,
                    transition: nil
                )
            },
            clips: sequence.clips.map { clip in
                ResolvedClip(
                    place: clip.place,
                    id: clip.id,
                    content: clip.content,
                    start: clip.start,
                    end: clip.end,
                    lane: clip.lane,
                    storyline: clip.storyline,
                    parent: clip.parent,
                    area: clip.area,
                    box: clip.box,
                    crop: clip.crop,
                    track: clip.track,
                    opacity: clip.opacity,
                    scale: clip.scale,
                    rotation: clip.rotation,
                    blend: clip.blend,
                    animation: .none
                )
            },
            audio: sequence.audio
        )
    }

    // The extent of every measured clip at sequence time 0, in the measuring space.
    private func extents(of sequence: ResolvedSequence) -> [Rectangle] {
        let parents = ParentEvaluator(sequence: sequence)
        let storyline = sequence.storyline.filter { $0.media != nil }.map { entry in
            let box = Rectangle(x: 0, y: 0, width: entry.box.size.width, height: entry.box.size.height)
            return bounds(of: box, by: entry.presentation(at: 0).transform)
        }
        let clips = sequence.clips.compactMap { clip in
            extent(of: clip, in: parents.space(of: clip, at: 0))
        }

        return storyline + clips
    }

    private func extent(
        of clip: ResolvedClip,
        in space: ClipSpace
    ) -> Rectangle? {
        switch clip.content {
        case .title:
            guard let box = clip.box else { return nil }

            let transform = clipEvaluator.childTransform(of: clip, in: space, at: 0)
            return bounds(of: Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height), by: transform)

        case .media:
            guard let box = clip.box else { return nil }

            // The child map carries the media's crop onto the box.
            let transform = clipEvaluator.childTransform(of: clip, in: space, at: 0)
            let drawn = clip.crop?.value(at: 0).rectangle
                ?? Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
            return bounds(of: drawn, by: transform)

        case let .shape(shape):
            return extent(of: shape, clip: clip, in: space)

        case .adjustment:
            return nil
        }
    }

    // A shape's outline grown by half its stroke width after its transform, with its arrowheads. A path's arrowheads
    // are measured as drawn, and a rect's or an ellipse's, which only a trim leaving part of it undrawn gives, by
    // growing its outline by the half width of their base. A shape at scale 0 draws nothing, so it is not measured.
    private func extent(
        of shape: ResolvedShape,
        clip: ResolvedClip,
        in space: ClipSpace
    ) -> Rectangle? {
        let sample = ClipSample(clip: clip, at: 0)
        let items = shapeEvaluator.items(of: shape, clip: clip, sample: sample, in: space, at: 0)
        guard let item = items.first, case let .path(path) = item.content else { return nil }

        let transform = item.transform
        switch path.geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            return bounds(of: rectangle.grown(by: path.drawnStroke?.reach ?? 0), by: transform)

        case let .polyline(points, isClosed):
            let scale = (transform.a * transform.a + transform.b * transform.b).squareRoot()
            let width = path.stroke?.width ?? 0
            let outline = Rectangle(bounding: points.map(transform.apply(to:))).grown(by: width / 2 * scale)
            let heads = arrowheads(of: points, isClosed: isClosed, path: path).map(transform.apply(to:))
            return heads.isEmpty ? outline : outline.union(Rectangle(bounding: heads))
        }
    }

    // The corners of a polyline's arrowheads as `DrawnStroke` lays them (FRAMES-11): each with its tip at its end of
    // the drawn stroke and its axis along the outline's direction there, as wide at its base as it is long.
    private func arrowheads(
        of points: [Point],
        isClosed: Bool,
        path: PathItem
    ) -> [Point] {
        let vertices = isClosed ? points + [points[0]] : points
        let segments = Array(zip(vertices, vertices.dropFirst()))
        let length = segments.reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
        guard let drawn = path.drawnStroke else { return [] }

        // The start's head points back along the outline, the end's forward.
        let ends = [
            (drawn.hasStartHead, drawn.start(along: length), -1.0),
            (drawn.hasEndHead, drawn.end(along: length), 1.0)
        ].filter(\.0)
        let head = drawn.headLength(along: length)
        return ends.flatMap { _, distance, sign -> [Point] in
            guard let (tip, direction) = place(at: distance, along: segments) else { return [] }

            let axis = Point(x: direction.x * sign, y: direction.y * sign)
            let base = Point(x: tip.x - axis.x * head, y: tip.y - axis.y * head)
            return [
                tip,
                Point(x: base.x - axis.y * head / 2, y: base.y + axis.x * head / 2),
                Point(x: base.x + axis.y * head / 2, y: base.y - axis.x * head / 2)
            ]
        }
    }

    // The point at a distance along segments and the unit direction they run there, on the segment that reaches it.
    private func place(
        at distance: Double,
        along segments: [(Point, Point)]
    ) -> (Point, Point)? {
        var start = 0.0
        var last: (Point, Point)?
        for (from, to) in segments {
            let length = hypot(to.x - from.x, to.y - from.y)
            guard length > 0 else { continue }

            let direction = Point(x: (to.x - from.x) / length, y: (to.y - from.y) / length)
            let along = min(max(distance - start, 0), length)
            last = (Point(x: from.x + direction.x * along, y: from.y + direction.y * along), direction)
            guard distance > start + length else { return last }

            start += length
        }
        return last
    }

    private func bounds(
        of rectangle: Rectangle,
        by transform: AffineTransform
    ) -> Rectangle {
        let corners = transform.apply(toCornersOf: rectangle)
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        let minX = xs.min() ?? rectangle.x
        let minY = ys.min() ?? rectangle.y
        return Rectangle(
            x: minX,
            y: minY,
            width: (xs.max() ?? rectangle.maxX) - minX,
            height: (ys.max() ?? rectangle.maxY) - minY
        )
    }

    // A storyline picture's box moves with the content. A solid has none, and fills the measured frame.
    private func moved(
        _ geometry: StorylineGeometry,
        by offset: Point
    ) -> StorylineGeometry {
        let appearance = geometry.appearance
        let box = appearance.box.map { box in
            ClipBox(size: box.size, position: box.position.map { moved($0, by: offset) }, anchor: box.anchor)
        }

        return StorylineGeometry(
            crop: geometry.crop,
            track: geometry.track,
            nested: geometry.nested,
            filter: geometry.filter,
            color: geometry.color,
            appearance: StorylineAppearance(
                box: box,
                opacity: appearance.opacity,
                scale: appearance.scale,
                rotation: appearance.rotation,
                blend: appearance.blend,
                radius: appearance.radius,
                border: appearance.border,
                shadow: appearance.shadow
            )
        )
    }

    private func moved(
        _ geometry: ClipGeometry,
        by offset: Point
    ) -> ClipGeometry {
        ClipGeometry(
            area: geometry.area?.map { area in
                FoundArea(
                    rectangle: moved(area.rectangle, by: offset),
                    target: moved(area.target, by: offset),
                    mediaTime: area.mediaTime,
                    lines: area.lines
                )
            },
            points: geometry.points?.map { points in points.map { moved($0, by: offset) } },
            position: geometry.position?.map { moved($0, by: offset) },
            box: geometry.box.map { box in
                ClipBox(size: box.size, position: box.position.map { moved($0, by: offset) }, anchor: box.anchor)
            },
            crop: geometry.crop,
            track: geometry.track,
            title: geometry.title,
            nested: geometry.nested,
            appearance: geometry.appearance
        )
    }

    private func moved(
        _ point: Point,
        by offset: Point
    ) -> Point {
        Point(x: point.x + offset.x, y: point.y + offset.y)
    }

    private func moved(
        _ rectangle: Rectangle,
        by offset: Point
    ) -> Rectangle {
        let origin = moved(Point(x: rectangle.x, y: rectangle.y), by: offset)
        return Rectangle(x: origin.x, y: origin.y, width: rectangle.width, height: rectangle.height)
    }
}
