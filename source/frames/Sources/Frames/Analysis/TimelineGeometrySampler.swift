//
//  TimelineGeometrySampler.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Where each clip of a resolved sequence lies at a sequence time, as `timeline --at` reports it (FRAMES-23): its box in
// the coordinates of its own space with the quad it lands on in output pixels, and the quad each mask's bounding
// rectangle lands on. Every map is the one evaluation draws the clip with: a clip outside its window holds the values of
// its window's edge and its parents are taken as they are at the time, a storyline clip carries its transition motion,
// and a clip with a corner pin lies on its plane, its animation acting inside its box B. Opacity, reveal and track
// mattes take no part. Where a corner pin lays no plane, every quad of its clip is the corner pin.
struct TimelineGeometrySampler: Sendable {
    // MARK: - Property
    private let sequence: ResolvedSequence
    private let parents: ParentEvaluator
    private let clipEvaluator = ClipEvaluator()
    private let shapeEvaluator = ShapeEvaluator()

    // MARK: - Initializer
    init(sequence: ResolvedSequence) {
        self.sequence = sequence
        self.parents = ParentEvaluator(sequence: sequence)
    }

    // MARK: - Public
    // A place no storyline clip holds is a connected or sequence clip's, and one no clip of the sequence holds is an
    // audio clip's, which resolve keeps only as sound and which lies nowhere.
    func geometry(
        at place: String,
        time: Double
    ) -> TimelineGeometry {
        if let index = sequence.storyline.firstIndex(where: { $0.place == place }) {
            return geometry(ofStoryline: index, at: time)
        }
        guard let clip = sequence.clips.first(where: { $0.place == place }) else { return .none }

        return geometry(of: clip, at: time)
    }

    // MARK: - Private
    // A storyline clip's media pixels are carried by its picture's map, onto its corner pin where it has one, and then
    // by its transition motion. A solid has no box and takes no mask.
    private func geometry(
        ofStoryline index: Int,
        at time: Double
    ) -> TimelineGeometry {
        let storyline = sequence.storyline
        let entry = storyline[index]
        guard entry.media != nil else { return .none }

        let sample = SampleInstant(frameTime: time)
        let valueTime = storyline.valueTime(ofEntry: index, in: sample)
        let motion = parents.motion(ofStoryline: index, at: sample)
        let plane: CornerPinPlane? = if let size = entry.cornerPin?.size, let quad = entry.cornerPin(at: valueTime) {
            CornerPinPlane(box: Rectangle(x: 0, y: 0, width: size.width, height: size.height), cornerPin: quad)
        } else {
            nil
        }
        let carry = { (transform: AffineTransform, rectangle: Rectangle) -> Quad in
            let quad = plane?.carry(Quad(rectangle), by: transform) ?? Quad(rectangle).carried(by: transform)
            return quad.carried(by: motion)
        }
        let crop = entry.crop(at: valueTime)

        return TimelineGeometry(
            box: TimelineBox(rect: crop, quad: carry(entry.pictureTransform(at: valueTime), crop)),
            masks: entry.masks(at: valueTime).map { carry($0.transform, $0.geometry.bounds()) }
        )
    }

    private func geometry(
        of clip: ResolvedClip,
        at time: Double
    ) -> TimelineGeometry {
        let valueTime = clip.valueTime(in: SampleInstant(frameTime: time))
        let space = parents.space(of: clip, at: valueTime)
        if clip.cornerPin != nil {
            return pinnedGeometry(of: clip, in: space, at: valueTime)
        }

        let transform = clipEvaluator.childTransform(of: clip, in: space, at: valueTime)
        let box = ownBox(of: clip, in: space, at: valueTime).map { box in
            TimelineBox(rect: box.rect, quad: Quad(box.rect).carried(by: box.ownSpace.concatenating(transform)))
        }
        let masks: [Quad]? = if case .null = clip.content {
            nil
        } else {
            clipEvaluator.masks(of: clip, in: space, at: valueTime).map { mask in
                Quad(mask.geometry.bounds()).carried(by: mask.transform)
            }
        }

        return TimelineGeometry(box: box, masks: masks)
    }

    // A clip with a corner pin drawn flat in its box B and carried onto its corner pin, then by its tracked motion and
    // its parent's map, as its group is drawn: a title's box is B and its text box lies inside it, a media clip's crop
    // is stretched onto B, and a rect's or an ellipse's box is B. An adjustment takes no corner pin.
    private func pinnedGeometry(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: SampleTime
    ) -> TimelineGeometry {
        guard
            case let .picture(content, _) = clip.content,
            let pin = clip.cornerPin,
            let written = clip.writtenCornerPin(areas: space.areas, clock: space.clock, at: time)
        else {
            return .none
        }

        let flat: (box: Rectangle, ownSpace: AffineTransform)
        switch content {
        case let .title(text):
            let drawn = text.box(at: time)
            flat = (Rectangle(x: 0, y: 0, width: drawn.width, height: drawn.height), text.textBoxInBox(at: time))

        case .media:
            let flatBox = Rectangle(x: 0, y: 0, width: pin.size.width, height: pin.size.height)
            let shown = clip.crop(at: time) ?? flatBox
            let crop = AffineTransform(translation: Point(x: -shown.x, y: -shown.y))
                .concatenating(AffineTransform(mapping: Size(width: shown.width, height: shown.height), onto: flatBox))
            flat = (flatBox, crop)

        case let .shape(shape):
            // A rect or an ellipse with a corner pin is placed by it and carries no box of its own.
            guard case let .box(width, height, _) = shape.geometry else { return .none }

            flat = (Rectangle(x: 0, y: 0, width: width.value(at: time), height: height.value(at: time)), .identity)

        case .adjustment:
            return .none
        }

        let size = Size(width: flat.box.width, height: flat.box.height)
        let cornerPin = clip.drawnCornerPin(box: size, areas: space.areas, clock: space.clock, at: time) ?? written
        let animation = ItemPresentation(area: flat.box, opacity: 1, motion: ClipSample(clip: clip, at: time).animation.motion)
            .transform
        let plane = CornerPinPlane(box: flat.box, cornerPin: cornerPin)
        let outer = space.tracked(by: clip.parentTrack, at: time).transform
        let carry = { (rectangle: Rectangle) -> Quad in
            plane.carry(Quad(rectangle), by: flat.ownSpace.concatenating(animation)).carried(by: outer)
        }

        let rect = ownBox(of: clip, in: space, at: time)?.rect ?? flat.box

        return TimelineGeometry(
            box: TimelineBox(rect: rect, quad: carry(rect)),
            masks: clip.ownMasks(at: time).map { carry($0.geometry.bounds()) }
        )
    }

    // The clip's box in the coordinates of its own space, and the map from them into the space it gives its children,
    // which `ClipEvaluator.childTransform` carries to output pixels: a title's box with its background in its text box,
    // a media clip's crop in its media pixels, a rect's, an ellipse's or a null's `[0, 0, w, h]` by `width` and `height`,
    // and for a shape or a null placed by its geometry its area or its path's curve's box in its parent's space. Nil for
    // an adjustment, which has no box.
    private func ownBox(
        of clip: ResolvedClip,
        in space: ClipSpace,
        at time: SampleTime
    ) -> (rect: Rectangle, ownSpace: AffineTransform)? {
        switch clip.content {
        case let .picture(.title(text), _):
            return (text.boxInTextBox(at: time), text.textBoxInBox(at: time))

        case .picture(.media, _):
            // Without a crop `ClipEvaluator.childTransform` carries a media clip by its box, which stands for its media.
            let size = clip.box?.size ?? clip.cornerPin?.size ?? Size(width: 0, height: 0)
            return (clip.crop(at: time) ?? Rectangle(x: 0, y: 0, width: size.width, height: size.height), .identity)

        case let .picture(.shape(shape), _):
            let sample = ClipSample(clip: clip, at: time)
            return shapeEvaluator.box(of: shape, clip: clip, sample: sample, in: space, at: time).map { ($0, .identity) }

        case let .null(null):
            switch null.geometry {
            case let .box(width, height):
                return (Rectangle(x: 0, y: 0, width: width.value(at: time), height: height.value(at: time)), .identity)

            case let .area(area, _):
                return (space.area(of: area, track: clip.parentTrack, at: time), .identity)
            }

        case .picture(.adjustment, _):
            return nil
        }
    }
}
