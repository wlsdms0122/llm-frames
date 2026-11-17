//
//  LabelPlacer.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Chooses the side a shape's label goes on: the first of the theme's `shapes.label.sides` where the label, outside the
// shape's box and centred along that side, fits inside the frame. The box is measured at one instant with the geometry
// evaluation would draw there and nothing of animation: keyframes interpolated by their eases, carried by the track,
// and shown through the storyline crop conformed into the frame. Everything else that moves the shape over time is
// evaluation's.
struct LabelPlacer: Sendable {
    // MARK: - Property
    private let conformer = CropConformer()
    private let sideFinder = LabelSideFinder()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `text` is the label set in the `label` style. `parent` is the picture a parented shape is on, and nil for a shape
    // without an area and for a sequence clip, whose area is in output pixels.
    func label(
        _ text: TextLayout,
        of clip: ClipPlan,
        written: Clip,
        area: PropertyValue<FoundArea>?,
        track: Track?,
        parent: ParentPicture?,
        storyline: [StorylinePlan],
        format: FormatPlan,
        theme: MergedTheme
    ) throws -> LabelPlan {
        let instant = self.instant(of: clip, storyline: storyline)
        let box = self.box(
            of: written,
            area: area,
            track: track,
            parent: parent,
            at: instant,
            format: format,
            theme: theme
        )
        let sides = theme.labelSides
        guard let side = sideFinder.side(of: text.size, beside: box, in: format.frame, sides: sides) else {
            throw ResolveError.labelWithoutRoom(
                place: written.place.appending(key: "label"),
                kind: .clip(clip.kind),
                label: written.label ?? "",
                sides: sides
            )
        }

        return LabelPlan(side: side, instant: instant, text: text, animation: clip.labelAnimation)
    }

    // MARK: - Private
    // A connected clip's first visible instant at which its storyline clip is out of every transition, or the middle
    // of its visible window when all of it falls in transitions. A sequence clip's first visible instant.
    private func instant(
        of clip: ClipPlan,
        storyline: [StorylinePlan]
    ) -> Double {
        guard let owner = clip.storyline else { return clip.visible.start }

        let next = storyline.indices.contains(owner + 1) ? storyline[owner + 1] : nil
        let steady = TimeRange(
            start: storyline[owner].transition?.range.end ?? -.infinity,
            end: next?.transition?.range.start ?? .infinity
        )

        return clip.visible.intersection(steady)?.start ?? (clip.visible.start + clip.visible.end) / 2
    }

    // The shape's box in output pixels: its area, or an arrow's from tail to head. A shape without an area covers the
    // frame.
    private func box(
        of written: Clip,
        area: PropertyValue<FoundArea>?,
        track: Track?,
        parent: ParentPicture?,
        at instant: Double,
        format: FormatPlan,
        theme: MergedTheme
    ) -> Rectangle {
        guard let area else { return format.frame }

        let rectangle = output(of: area, track: track, parent: parent, at: instant, format: format)
        guard case let .shape(.arrow(side)) = written.content else { return rectangle }

        // Theme lengths stay in output pixels under a zoom.
        let scale = theme.lengthScale(at: format.size.width)

        return Arrow(pointingAt: rectangle, from: side, theme: theme, scale: scale).box
    }

    // A sequence clip's area is in output pixels. A parented one is in its picture, carried by its own track, and
    // shown through the picture's crop, which its storyline clip's track carries. No crop is the whole picture, as it
    // is at the storyline clip's `in`.
    private func output(
        of area: PropertyValue<FoundArea>,
        track: Track?,
        parent: ParentPicture?,
        at instant: Double,
        format: FormatPlan
    ) -> Rectangle {
        guard let parent else { return value(of: area, at: instant, mediaTime: instant, track: nil) }

        let mediaTime = parent.plan.mediaTime(atSequenceTime: instant)

        return conformer.output(
            of: value(of: area, at: instant, mediaTime: mediaTime, track: track),
            crop: crop(of: parent, at: instant, mediaTime: mediaTime, format: format),
            box: format.frame
        )
    }

    // The parent picture's crop at the instant as evaluation draws it: each crop conformed, brought back through its
    // track at its own time, interpolated as a `Crop`, and carried by the motion at the instant. A band crop takes only
    // the vertical move of the motion, so it keeps its ratio.
    private func crop(
        of parent: ParentPicture,
        at instant: Double,
        mediaTime: Double,
        format: FormatPlan
    ) -> Rectangle {
        let whole = FoundArea(
            rectangle: parent.picture.bounds,
            target: parent.picture.bounds,
            isBand: false,
            mediaTime: parent.plan.mediaTime(atSequenceTime: parent.plan.instant),
            lines: []
        )
        let values = switch parent.geometry.crop ?? .value(whole) {
        case let .value(found):
            [TimedValue(index: 0, at: instant, value: found, ease: .linear)]

        case let .keyframes(keyframes):
            keyframes
        }
        let isBand = values.allSatisfy(\.value.isBand)
        let track = parent.geometry.track
        let keyframes = values.map { timed in
            let motion = track?.motion(atMediaTime: timed.value.mediaTime) ?? .identity
            let crop = conformer.conformed(timed.value.rectangle, to: format.frame, by: format.conform)

            return Keyframe(
                at: timed.at,
                value: Crop(isBand ? motion.bringBackBandCrop(crop) : motion.bringBack(crop)),
                ease: timed.ease
            )
        }

        let interpolated = keyframes.value(at: instant).rectangle
        let motion = track?.motion(atMediaTime: mediaTime) ?? .identity

        return isBand ? motion.carryBandCrop(interpolated) : motion.carry(interpolated)
    }

    // A property at the instant, `mediaTime` in its picture: each value, `shaped` as found, brought back through the
    // track's motion at its own time, interpolated there by the keyframes' eases, and carried by the motion at the
    // instant. A band keeps the full width of its picture.
    private func value(
        of property: PropertyValue<FoundArea>,
        at instant: Double,
        mediaTime: Double,
        track: Track?
    ) -> Rectangle {
        let values = switch property {
        case let .value(found):
            [TimedValue(index: 0, at: instant, value: found, ease: .linear)]

        case let .keyframes(keyframes):
            keyframes
        }
        let isBand = values.allSatisfy(\.value.isBand)
        let keyframes = values.map { timed in
            let motion = track?.motion(atMediaTime: timed.value.mediaTime) ?? .identity
            let rectangle = timed.value.rectangle

            return Keyframe(
                at: timed.at,
                value: isBand ? motion.bringBackBand(rectangle) : motion.bringBack(rectangle),
                ease: timed.ease
            )
        }

        let interpolated = keyframes.value(at: instant)
        let motion = track?.motion(atMediaTime: mediaTime) ?? .identity

        return isBand ? motion.carryBand(interpolated) : motion.carry(interpolated)
    }
}
