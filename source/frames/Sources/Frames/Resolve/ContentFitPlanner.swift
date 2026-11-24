//
//  ContentFitPlanner.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

import Foundation

// Measures a content-fit frame from a sequence planned in its measuring space, and moves what is written in that
// space onto the measured frame. Each clip's extent is its geometry at sequence time 0 without animation or transition
// motion, its parent's included, as evaluation carries it: a storyline picture's or media clip's box, a title's box
// with its highlights and underlines, and a shape's outline with its stroke, joins, caps and arrowheads. A solid fills
// the frame and an adjustment applies to it, so neither is measured, and nor is a clip used as a track matte, which is
// not drawn. A clip placed by its placement is placed on the frame, so neither it nor any clip placed from it, through
// a parent or a clip area, is measured, and it is placed on the measured frame in place of being moved.
struct ContentFitPlanner: Sendable {
    // MARK: - Property
    private let clipEvaluator = ClipEvaluator()
    private let shapeEvaluator = ShapeEvaluator()
    private let areaFinder = ClipAreaFinder()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `plan` is planned on a frame the size of its first storyline picture's box, and its storyline has a picture.
    func fitted(
        _ plan: SequencePlan,
        margin: Margin
    ) throws -> SequencePlan {
        let still = try self.still(ResolvedSequence(plan: plan, hashes: PlaceholderHasher()))
        let placed = placedOnFrame(plan)
        let extents = extents(of: still, without: placed)
        guard let union = extents.reduce(nil, { union, extent in union?.union(extent) ?? extent }) else {
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
            colorSpace: plan.format.colorSpace,
            peak: plan.format.peak,
            compositing: plan.format.compositing,
            shutter: plan.format.shutter,
            margin: margin
        )

        return SequencePlan(
            time: plan.time,
            format: format,
            storyline: plan.storyline.map { moved($0, by: offset) },
            clips: plan.clips.indices.map { index in
                plan.clips[index].isInOutputPixels
                    ? moved(plan.clips[index], in: plan.time.clips[index].space, by: offset, onto: format.frame)
                    : plan.clips[index]
            },
            sound: plan.sound,
            audioFilter: plan.audioFilter
        )
    }

    // MARK: - Private
    // The sequence as content fit measures it: no clip animates and no storyline clip transitions.
    private func still(_ sequence: ResolvedSequence) -> ResolvedSequence {
        ResolvedSequence(
            format: sequence.format,
            storyline: sequence.storyline.map { entry in
                ResolvedStorylineClip(
                    place: entry.place,
                    id: entry.id,
                    media: entry.media,
                    solid: entry.solid,
                    colorSpace: entry.colorSpace,
                    isToneMapped: entry.isToneMapped,
                    in: entry.in,
                    out: entry.out,
                    speed: entry.speed,
                    timeRemap: entry.timeRemap,
                    start: entry.start,
                    end: entry.end,
                    crop: entry.crop,
                    mask: entry.mask,
                    trackMatte: entry.trackMatte,
                    track: entry.track,
                    filter: entry.filter,
                    box: entry.box,
                    cornerPin: entry.cornerPin,
                    opacity: entry.opacity,
                    scale: entry.scale,
                    rotation: entry.rotation,
                    blend: entry.blend,
                    isMotionBlurred: entry.isMotionBlurred,
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
                    box: clip.box,
                    cornerPin: clip.cornerPin,
                    crop: clip.crop,
                    mask: clip.mask,
                    trackMatte: clip.trackMatte,
                    track: clip.track,
                    opacity: clip.opacity,
                    scale: clip.scale,
                    rotation: clip.rotation,
                    blend: clip.blend,
                    isMotionBlurred: clip.isMotionBlurred,
                    animation: .none
                )
            },
            audio: sequence.audio,
            audioFilter: sequence.audioFilter
        )
    }

    // The places of the clips that depend on the frame: a clip placed by its placement, and a clip parented to one that
    // does or whose geometry takes the box of one through a clip area. Parents and clip areas hold no cycle, so the
    // walk ends.
    private func placedOnFrame(_ plan: SequencePlan) -> Set<String> {
        let clips = plan.time.clips
        let written = plan.time.sequence.storyline.flatMap(\.connected) + plan.time.sequence.clips
        let named = written.map(areaFinder.named(by:))
        var isPlaced = plan.clips.map { $0.box?.placement != nil }
        var isGrowing = true
        while isGrowing {
            isGrowing = false
            for index in clips.indices where !isPlaced[index] {
                let isParentPlaced = if case let .clip(parent, _) = clips[index].parent {
                    isPlaced[parent]
                } else {
                    false
                }
                let isAreaPlaced = named[index].contains { id in
                    clips.indices.contains { isPlaced[$0] && clips[$0].id == id }
                }
                guard isParentPlaced || isAreaPlaced else { continue }

                isPlaced[index] = true
                isGrowing = true
            }
        }

        return Set(clips.indices.filter { isPlaced[$0] }.map { clips[$0].place.description })
    }

    // The extent of every measured clip at sequence time 0, in the measuring space, `placed` naming the places of the
    // clips that depend on the frame. A storyline picture with a corner pin covers the quadrilateral of its four
    // points.
    private func extents(
        of sequence: ResolvedSequence,
        without placed: Set<String>
    ) -> [Rectangle] {
        let parents = ParentEvaluator(sequence: sequence)
        let storyline = sequence.storyline.filter { $0.media != nil }.compactMap { entry -> Rectangle? in
            if let pin = entry.cornerPin {
                return Rectangle(bounding: pin.points.mapValues { $0.sampled(\.fixed) }.value(at: SampleTime(0)).corners)
            }
            guard let box = entry.box else { return nil }

            let rectangle = Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
            return bounds(of: rectangle, by: entry.presentation(at: SampleTime(0)).transform)
        }
        let clips = sequence.clips.filter { !sequence.isMatte($0) && !placed.contains($0.place) }.compactMap { clip in
            extent(of: clip, in: parents.space(of: clip, at: SampleTime(0)))
        }

        return storyline + clips
    }

    private func extent(
        of clip: ResolvedClip,
        in space: ClipSpace
    ) -> Rectangle? {
        switch clip.content {
        case let .title(text):
            // The child map places the title's box at the time, and its glyphs item lies in its text box inside it.
            let time = SampleTime(0)
            let transform = text.textBoxInBox(at: time)
                .concatenating(clipEvaluator.childTransform(of: clip, in: space, at: time))
            return GlyphsItem(text: text, factor: 1, at: time).filledRects()
                .map { bounds(of: $0, by: transform) }
                .reduce(nil) { union, extent in union?.union(extent) ?? extent }

        case .media:
            guard let box = clip.box else { return nil }

            // The child map carries the media's crop onto the box.
            let transform = clipEvaluator.childTransform(of: clip, in: space, at: SampleTime(0))
            let drawn = clip.crop(at: SampleTime(0))
                ?? Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
            return bounds(of: drawn, by: transform)

        case let .shape(shape):
            return extent(of: shape, clip: clip, in: space)

        case .adjustment:
            return nil
        }
    }

    // What a shape draws after its transform, without its shadow. A shape at scale 0 draws nothing, so it is not
    // measured.
    private func extent(
        of shape: ResolvedShape,
        clip: ResolvedClip,
        in space: ClipSpace
    ) -> Rectangle? {
        let sample = ClipSample(clip: clip, at: SampleTime(0))
        let items = shapeEvaluator.items(of: shape, clip: clip, sample: sample, in: space, at: SampleTime(0))
        guard let item = items.first, case let .path(path) = item.content else { return nil }

        return path.drawnBounds(carriedBy: item.transform, under: item.transform)
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

    // A storyline picture's box or corner pin moves with the content. A solid has neither, and fills the measured frame.
    private func moved(
        _ geometry: StorylineGeometry,
        by offset: Point
    ) -> StorylineGeometry {
        let appearance = geometry.appearance
        let box = appearance.box.map { box in
            ClipBox(size: box.size, position: box.position.map { $0.map { moved($0, by: offset) } }, anchor: box.anchor)
        }
        let cornerPin = appearance.cornerPin.map { pin in
            ClipCornerPin(size: pin.size, points: pin.points.map { $0.map { moved($0, by: offset) } })
        }

        return StorylineGeometry(
            crop: geometry.crop,
            mask: geometry.mask,
            track: geometry.track,
            nested: geometry.nested,
            filter: geometry.filter,
            solid: geometry.solid,
            appearance: StorylineAppearance(
                box: box,
                cornerPin: cornerPin,
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

    // A mask moves with the content only where it is in the clip's parent's space: an adjustment's, or a shape's placed
    // by its geometry. A title's or a box shape's is in its box and a media clip's in its media. A clip area moves with
    // the clip it names. A path's tangents are offsets, which a move leaves as they are. A box placed by its placement
    // is placed on `frame`, the measured frame, and not moved.
    private func moved(
        _ geometry: ClipGeometry,
        in space: OwnSpace,
        by offset: Point,
        onto frame: Rectangle
    ) -> ClipGeometry {
        ClipGeometry(
            area: geometry.area?.map { area in
                area.map { area in
                    FoundArea(
                        rectangle: moved(area.rectangle, by: offset),
                        target: moved(area.target, by: offset),
                        mediaTime: area.mediaTime,
                        lines: area.lines
                    )
                }
            },
            points: geometry.points?.map { vertex in
                vertex.map(vertex: { $0.mapValues { $0.map { moved($0, by: offset) } } }, tangent: { $0 })
            },
            position: geometry.position?.map { $0.map { moved($0, by: offset) } },
            box: geometry.box.map { box in placed(box, by: offset, onto: frame) },
            cornerPin: geometry.cornerPin.map { pin in
                ClipCornerPin(size: pin.size, points: pin.points.map { $0.map { moved($0, by: offset) } })
            },
            crop: geometry.crop,
            mask: space == .parent
                ? geometry.mask?.map { mask in
                    mask.carried(
                        area: { area, _, _ in moved(area, by: offset) },
                        point: { point, _, _ in moved(point, by: offset) },
                        tangent: { tangent, _ in tangent },
                        scale: { _ in 1 }
                    )
                }
                : geometry.mask,
            track: geometry.track,
            isInOutputPixels: geometry.isInOutputPixels,
            title: geometry.title,
            nested: geometry.nested,
            appearance: geometry.appearance
        )
    }

    // A box placed by its position moves with the content, and one placed by its placement is placed on the frame.
    private func placed(
        _ box: ClipBox,
        by offset: Point,
        onto frame: Rectangle
    ) -> ClipBox {
        guard let placement = box.placement else {
            return ClipBox(
                size: box.size,
                position: box.position.map { $0.map { moved($0, by: offset) } },
                anchor: box.anchor
            )
        }

        let position = placement.position(of: box.size, anchor: box.anchor, in: frame)
        return ClipBox(size: box.size, position: .value(.point(position)), anchor: box.anchor, placement: placement)
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
