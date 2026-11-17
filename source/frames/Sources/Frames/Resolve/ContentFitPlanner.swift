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
// box, and a box, fill or arrow shape's outline grown by half its stroke, with its head. A solid fills the frame, an
// adjustment applies to it, a shape without an area covers it and a dim darkens it, so none of them is measured. The
// union is rounded outward to whole pixels, the margin is added, and each side is rounded up to an even number.
struct ContentFitPlanner: Sendable {
    // MARK: - Property
    private let clipEvaluator = ClipEvaluator()
    private let shapeEvaluator = ShapeEvaluator()
    private let drawer = ShapeDrawer()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `plan` is planned on a frame the size of its first storyline picture's box, and its storyline has a picture.
    func fitted(
        _ plan: SequencePlan,
        margin: Margin
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
        let time = plan.time

        return SequencePlan(
            time: time,
            format: format,
            storyline: time.storyline.indices.map { index in
                moved(plan.storyline[index], isSolid: time.storyline[index].source.media == nil, by: offset, on: format)
            },
            clips: time.clips.indices.map { index in
                isInMeasuringSpace(time.clips[index].parent, time: time)
                    ? moved(plan.clips[index], by: offset)
                    : plan.clips[index]
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

        case let .shape(drawing):
            return extent(of: drawing, clip: clip, in: space)

        case .adjustment:
            return nil
        }
    }

    // A shape at scale 0 draws nothing, so it is not measured.
    private func extent(
        of drawing: ShapeDrawing,
        clip: ResolvedClip,
        in space: ClipSpace
    ) -> Rectangle? {
        guard let keyframes = clip.area else { return nil }

        let tracked = space.tracked(by: clip.track, at: 0)
        guard tracked.scale > 0 else { return nil }

        let area = space.area(of: keyframes, track: clip.track, at: 0)
        let drawn = drawer.content(of: drawing, on: area, scale: tracked.scale)
        let outline: Rectangle
        switch drawn.content {
        case let .box(rectangle, width, _, _):
            outline = rectangle.grown(by: width / 2)

        case let .fill(rectangle, _):
            outline = rectangle

        case .arrow:
            outline = drawn.box

        case .dim:
            return nil
        }

        let sample = ClipSample(clip: clip, at: 0)
        let transform = shapeEvaluator.transform(of: drawing, clip: clip, sample: sample, in: space, at: 0)
        return bounds(of: outline, by: transform)
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

    // An unparented clip, one parented to a solid, whose space is the frame's output pixels, and one under a chain of
    // shapes and adjustments that reaches neither a storyline picture nor a box clip are written in measuring space.
    private func isInMeasuringSpace(
        _ parent: ClipParent?,
        time: TimePlan
    ) -> Bool {
        switch parent {
        case .none:
            return true

        case let .storyline(index, _):
            return time.storyline[index].source.media == nil

        case let .clip(index, _):
            let plan = time.clips[index]
            switch plan.kind {
            case .shape, .adjust:
                // ParentFinder has ruled out a cycle, so the chain ends.
                return isInMeasuringSpace(plan.parent, time: time)

            default:
                return false
            }
        }
    }

    // A storyline picture's box moves with the content, and a solid's is the measured frame.
    private func moved(
        _ geometry: StorylineGeometry,
        isSolid: Bool,
        by offset: Point,
        on format: FormatPlan
    ) -> StorylineGeometry {
        let appearance = geometry.appearance
        let box = isSolid
            ? ClipBox(size: format.size, position: .value(Point(x: 0, y: 0)), anchor: format.frame.center)
            : ClipBox(
                size: appearance.box.size,
                position: appearance.box.position.map { moved($0, by: offset) },
                anchor: appearance.box.anchor
            )

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
