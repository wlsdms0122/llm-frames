//
//  SequencePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what resolve decides for one sequence before evaluation, from its time plan. A content-fit sequence is planned
// in its measuring space on a frame the size of its first storyline picture's box, which gives its length scale, and
// then measured.
struct SequencePlanner: Sendable {
    // MARK: - Property
    private let finder: GeometryFinder
    private let tracker: TrackPlanner
    private let titles: TitlePlanner
    private let sound: SoundPlanner
    private let appearances: ClipAppearancePlanner
    private let contentFit = ContentFitPlanner()
    private let cropChecker = CropChecker()

    // MARK: - Initializer
    init(
        tracker: any TrackerProvider,
        shaper: any ShapingProvider,
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.finder = GeometryFinder()
        self.tracker = TrackPlanner(tracker: tracker)
        self.titles = TitlePlanner(shaper: shaper, library: library)
        self.sound = SoundPlanner(presets: presets, library: library)
        self.appearances = ClipAppearancePlanner(presets: presets, library: library)
    }

    // MARK: - Public
    func plan(_ time: TimePlan) throws -> SequencePlan {
        // A compound clip's or a document's picture is its nested document's output, so the nested plans come first.
        let storylineNested = try time.storyline.map { plan in try plan.source.media.flatMap(nested) }
        let clipNested = try time.clips.map { plan in try plan.media.flatMap(nested) }
        let crops = try time.storyline.indices.map { index in
            try crop(of: time.storyline[index], written: time.sequence.storyline[index], nested: storylineNested[index])
        }
        let format = try self.format(of: time, nested: storylineNested, crops: crops)
        let lengthScale = time.theme.lengthScale(at: format.size.width)
        let storylineMasks = try time.storyline.indices.map { index in
            try mask(of: time.storyline[index], written: time.sequence.storyline[index], lengthScale: lengthScale)
        }
        let written = time.sequence.storyline.flatMap(\.connected) + time.sequence.clips
        let clipPictures = try time.clips.indices.map { index in
            try picture(
                of: time.clips[index],
                nested: clipNested[index],
                place: written[index].place.appending(key: "media")
            )
        }
        let found = try time.clips.indices.map { index in
            try geometry(
                of: time.clips[index],
                written: written[index],
                picture: clipPictures[index],
                time: time,
                lengthScale: lengthScale
            )
        }

        let storylinePositions = try time.storyline.indices.map { index in
            try position(of: time.storyline[index], written: time.sequence.storyline[index])
        }
        let storylineCornerPins = try time.storyline.indices.map { index in
            try cornerPin(of: time.storyline[index], written: time.sequence.storyline[index])
        }

        let tracked = try tracker.plan(
            time,
            storylineCrops: crops,
            storylineMasks: storylineMasks,
            crops: found.map(\.crop),
            areas: found.map(\.area),
            masks: found.map { $0.mask?.map(\.mask) },
            cornerPins: found.map(\.cornerPin)
        )
        try checkKeyframes(of: tracked.time)
        let shapes = try tracked.time.clips.indices.map { index in
            try appearances.shape(
                of: tracked.time.clips[index],
                written: written[index],
                scale: lengthScale,
                theme: time.theme
            )
        }
        let placed = time.clips.indices.map { index in
            (
                area: found[index].area,
                points: points(of: tracked.time.clips[index], found: found[index].points, written: written[index]),
                position: found[index].position,
                cornerPin: found[index].cornerPin,
                crop: found[index].crop,
                mask: masks(of: tracked.time.clips[index], found: found[index].mask, written: written[index])
            )
        }

        let storyline = try time.storyline.indices.map { index in
            let box = try box(
                of: time.storyline[index],
                crop: crops[index],
                nested: storylineNested[index],
                format: format
            )
            try checkCrop(
                crops[index],
                of: time.storyline[index],
                written: time.sequence.storyline[index],
                box: box,
                nested: storylineNested[index],
                format: format
            )

            return StorylineGeometry(
                crop: crops[index],
                mask: storylineMasks[index],
                track: tracked.storyline[index],
                isCropOnTrackFrame: time.sequence.storyline[index].isCropOnTrackFrame,
                nested: storylineNested[index],
                filter: try appearances.filter(
                    time.sequence.storyline[index].filter,
                    key: "filter",
                    of: time.sequence.storyline[index].place,
                    kind: time.storyline[index].source.kind,
                    media: time.sequence.storyline[index].media,
                    clock: time.storyline[index].map,
                    instant: time.storyline[index].instant,
                    scale: lengthScale,
                    theme: time.theme
                ),
                solid: try appearances.solid(
                    of: time.sequence.storyline[index],
                    plan: time.storyline[index],
                    theme: time.theme
                ),
                appearance: try appearances.appearance(
                    of: time.storyline[index],
                    written: time.sequence.storyline[index],
                    position: storylinePositions[index],
                    cornerPin: storylineCornerPins[index],
                    box: box,
                    format: format,
                    scale: lengthScale,
                    theme: time.theme
                )
            )
        }
        let clips = try tracked.time.clips.indices.map { index in
            let title = try title(of: tracked.time.clips[index], written: written[index], scale: lengthScale, time: time)
            let shape = shapes[index]
            let box = try appearances.box(
                of: tracked.time.clips[index],
                written: written[index],
                position: placed[index].position,
                crop: placed[index].crop,
                title: title?.layout,
                picture: clipPictures[index],
                shape: shape,
                format: format,
                theme: time.theme
            )
            let cornerPin = try appearances.cornerPin(
                of: tracked.time.clips[index],
                written: written[index],
                points: placed[index].cornerPin,
                track: tracked.clips[index],
                crop: placed[index].crop,
                title: title?.layout,
                picture: clipPictures[index],
                shape: shape,
                format: format
            )
            return ClipGeometry(
                area: placed[index].area,
                points: placed[index].points,
                position: placed[index].position,
                box: box,
                cornerPin: cornerPin,
                crop: placed[index].crop,
                mask: placed[index].mask,
                track: tracked.clips[index],
                onTrackFrame: tracked.time.clips[index].onTrackFrame(of: written[index]),
                isInOutputPixels: found[index].isInOutputPixels,
                title: title,
                nested: clipNested[index],
                appearance: try appearances.appearance(
                    of: tracked.time.clips[index],
                    written: written[index],
                    box: box?.size ?? cornerPin?.size,
                    crop: placed[index].crop,
                    picture: clipPictures[index],
                    shape: shape,
                    scale: lengthScale,
                    theme: time.theme
                )
            )
        }

        let sound = try self.sound.sound(
            of: tracked.time,
            written: written,
            storylineNested: storylineNested,
            clipNested: clipNested
        )

        let plan = SequencePlan(
            time: tracked.time,
            format: format,
            storyline: storyline,
            clips: clips,
            sound: sound,
            audioFilter: try self.sound.audioFilter(of: tracked.time)
        )
        guard let margin = format.margin else { return plan }

        return try contentFit.fitted(plan, margin: margin)
    }

    // MARK: - Private
    private func nested(_ media: MediaPlan) throws -> SequencePlan? {
        switch media.source {
        case .file:
            nil

        case let .sequence(nested):
            try plan(nested)
        }
    }

    // The background is the theme `background` unless the format gives one. A content-fit frame is the size of its
    // first storyline picture's box until it is measured.
    private func format(
        of time: TimePlan,
        nested: [SequencePlan?],
        crops: [PropertyValue<Rectangle>?]
    ) throws -> FormatPlan {
        let format = time.sequence.format
        let colorSpace = format.colorSpace ?? .srgb
        let size: Size
        let margin: Margin?
        switch format.size {
        case let .fixed(written):
            size = written
            margin = nil

        case .none:
            size = try defaultSize(of: time, nested: nested)
            margin = nil

        case let .content(written):
            let boxes = try time.storyline.indices.compactMap { index in
                try pictureBox(of: time.storyline[index], crop: crops[index], nested: nested[index])
            }
            guard let first = boxes.first else {
                throw ResolveError.contentFitWithoutPicture(
                    place: time.sequence.place.appending(key: "format").appending(key: "size"),
                    kind: .sequence
                )
            }

            size = first
            margin = written
        }

        return FormatPlan(
            size: size,
            conform: format.conform ?? .fit,
            background: time.theme.color(format.background ?? "background"),
            fps: time.fps,
            duration: time.duration,
            colorSpace: colorSpace,
            peak: colorSpace == .rec2100PQ ? format.peak ?? colorSpace.peakLuminance : nil,
            compositing: format.compositing ?? .encoded,
            shutter: Shutter(
                angle: format.shutterAngle ?? Shutter.default.angle,
                phase: format.shutterPhase ?? Shutter.default.phase,
                samplesPerFrame: format.samplesPerFrame ?? Shutter.default.samplesPerFrame
            ),
            margin: margin
        )
    }

    // A storyline clip's box is the frame, and under content fit the pixel size of its picture's crop at scale 1: its
    // first crop's, or its whole picture's without one. A solid has none, since it fills the frame.
    private func box(
        of plan: StorylinePlan,
        crop: PropertyValue<Rectangle>?,
        nested: SequencePlan?,
        format: FormatPlan
    ) throws -> Size? {
        guard plan.source.media != nil else { return nil }
        guard format.isMeasured else { return format.size }

        return try pictureBox(of: plan, crop: crop, nested: nested)
    }

    // A storyline clip's crop fills its box by the format's `conform`.
    private func checkCrop(
        _ crop: PropertyValue<Rectangle>?,
        of plan: StorylinePlan,
        written: StorylineClip,
        box: Size?,
        nested: SequencePlan?,
        format: FormatPlan
    ) throws {
        guard crop != nil, let box, let media = plan.source.media else { return }

        let picture = try self.picture(
            of: media,
            kind: plan.source.kind,
            nested: nested,
            place: plan.place.appending(key: "media")
        )
        try cropChecker.check(
            crop,
            of: picture,
            box: box,
            conform: format.conform,
            isTracked: written.track != nil,
            place: written.place.appending(key: "crop"),
            kind: .clip(plan.source.kind)
        )
    }

    // The pixel size of a storyline clip's crop at scale 1, nil for a solid, which has no picture of its own.
    private func pictureBox(
        of plan: StorylinePlan,
        crop: PropertyValue<Rectangle>?,
        nested: SequencePlan?
    ) throws -> Size? {
        guard let media = plan.source.media else { return nil }

        if let first = crop?.firstValue {
            return Size(width: first.width, height: first.height)
        }
        let place = plan.place.appending(key: "media")
        return try picture(of: media, kind: plan.source.kind, nested: nested, place: place).size
    }

    // The size of the first video on the storyline, or of the first storyline clip when there is no video, rounded to
    // even numbers. A solid has no size of its own.
    private func defaultSize(
        of time: TimePlan,
        nested: [SequencePlan?]
    ) throws -> Size {
        let index = time.storyline.firstIndex { $0.source.kind == .media(.video) } ?? 0
        let plan = time.storyline[index]
        guard let media = plan.source.media else {
            throw ResolveError.missingFormatSize(place: time.sequence.place, kind: .sequence)
        }

        let size = try picture(
            of: media,
            kind: plan.source.kind,
            nested: nested[index],
            place: plan.place.appending(key: "media")
        ).size
        return Size(width: (size.width / 2).rounded() * 2, height: (size.height / 2).rounded() * 2)
    }

    // A media file's picture is its probed size. A compound clip's is the output frame of its nested sequence, which is
    // drawn, not read.
    private func picture(
        of media: MediaPlan,
        kind: ClipKind,
        nested: SequencePlan?,
        place: Place
    ) throws -> Picture {
        if let nested {
            return Picture(name: media.reference ?? place.description, size: nested.format.size)
        }
        // Media without a nested plan is a file.
        guard case let .file(file) = media.source, let size = file.size else {
            let reference = media.reference ?? place.description
            throw ResolveError.soundAsPicture(place: place, kind: .clip(kind), reference: reference)
        }

        return Picture(
            name: media.reference ?? file.path,
            size: size,
            colorSpace: media.colorSpace
        )
    }

    // A drawn media clip's picture, which its crop, its box and how it fills it are all found in. Audio is drawn by
    // nothing, so it has none.
    private func picture(
        of plan: ClipPlan,
        nested: SequencePlan?,
        place: Place
    ) throws -> Picture? {
        guard plan.kind != .media(.audio), let media = plan.media else { return nil }

        return try picture(of: media, kind: plan.kind, nested: nested, place: place)
    }

    // A solid takes no crop.
    private func crop(
        of plan: StorylinePlan,
        written: StorylineClip,
        nested: SequencePlan?
    ) throws -> PropertyValue<Rectangle>? {
        guard let crop = written.crop, let media = plan.source.media else { return nil }

        let picture = try self.picture(
            of: media,
            kind: plan.source.kind,
            nested: nested,
            place: plan.place.appending(key: "media")
        )
        return try finder.crops(
            crop,
            in: picture,
            clock: plan.map,
            place: written.place,
            kind: plan.source.kind.label
        )
    }

    // A storyline clip's mask is in the media pixels of its own media, as its crop is. A solid takes none. A tracked
    // clip's mask leaf written without keyframes is true on the track's frame.
    private func mask(
        of plan: StorylinePlan,
        written: StorylineClip,
        lengthScale: Double
    ) throws -> [ResolvedMask]? {
        guard let mask = written.mask, plan.source.media != nil else { return nil }

        let planner = MaskPlanner(
            finder: finder,
            place: written.place,
            kind: .clip(plan.source.kind),
            clock: plan.map,
            instant: plan.instant,
            lengthScale: lengthScale
        )
        return try planner.masks(mask)?
            .map { found in
                guard written.track != nil else { return found.mask }

                return found.mask.onTrackFrame { leaf in found.staticLeaves.contains(leaf) }
            }
    }

    // A storyline clip has no parent, so its position is in output pixels.
    private func position(
        of plan: StorylinePlan,
        written: StorylineClip
    ) throws -> PropertyValue<Point>? {
        guard let position = written.position else { return nil }

        // ClipAreaFinder has stopped a clip area on a storyline clip.
        return try finder.positions(
            position,
            clock: plan.map,
            lengthScale: 1,
            place: written.place,
            kind: plan.source.kind.label
        ).map(\.fixed)
    }

    // A storyline clip has no parent, so its corner pin is in output pixels, and it has no parent's media to track, so
    // `track` stops beside it (FRAMES-12).
    private func cornerPin(
        of plan: StorylinePlan,
        written: StorylineClip
    ) throws -> PropertyValue<[GeometryPoint]>? {
        guard let cornerPin = written.cornerPin else { return nil }

        if written.track != nil {
            let place = switch cornerPin {
            case .value:
                written.place.appending(key: "cornerPin")

            case let .keyframes(keyframes):
                written.place.appending(key: "keyframes").appending(index: keyframes.map(\.index).min() ?? 0)
                    .appending(key: "cornerPin")
            }
            throw ResolveError.trackOnStorylineCornerPin(place: place, kind: .clip(plan.source.kind))
        }
        // ClipAreaFinder has stopped a clip area on a storyline clip.
        return try finder.points(
            cornerPin,
            key: "cornerPin",
            clock: plan.map,
            lengthScale: 1,
            place: written.place,
            kind: plan.source.kind.label
        )
    }

    // A parented clip's area and position are in its parent's space, and an unparented clip's in output pixels, as are
    // those of a clip parented to a solid or under a chain of shapes and adjustments that reaches neither a storyline
    // picture nor a clip with a box. A media clip's crop is in its own picture. A mask is in the clip's own coordinate
    // space: a media clip's media, a title's or a box shape's box, and for a shape placed by its geometry or an
    // adjustment the space its parent gives, where a clip area names a box drawn there.
    private func geometry(
        of plan: ClipPlan,
        written: Clip,
        picture: Picture?,
        time: TimePlan,
        lengthScale: Double
    ) throws -> FoundGeometry {
        let area = try written.area.map { area in
            try finder.areas(
                area,
                key: "area",
                clock: plan.clock,
                lengthScale: lengthScale,
                place: written.place,
                kind: plan.kind.label
            )
        }
        let vertices = try shapePoints(of: written).map { points in
            try finder.vertices(
                points.vertices,
                clock: plan.clock,
                lengthScale: lengthScale,
                place: { index, keyframe in points.place(ofPoint: index, keyframe: keyframe, in: written.place) },
                kind: plan.kind.label
            )
        }
        let cornerPin = try written.cornerPin.map { cornerPin in
            try finder.points(
                cornerPin,
                key: "cornerPin",
                clock: plan.clock,
                lengthScale: lengthScale,
                place: written.place,
                kind: plan.kind.label
            )
        }
        let position = try written.position.map { position in
            try finder.positions(
                position,
                clock: plan.clock,
                lengthScale: lengthScale,
                place: written.place,
                kind: plan.kind.label
            )
        }
        let crop = try written.crop.flatMap { crop in
            try picture.map { picture in
                try finder.crops(
                    crop,
                    in: picture,
                    clock: plan.clock,
                    place: written.place,
                    kind: plan.kind.label
                )
            }
        }

        let planner = MaskPlanner(
            finder: finder,
            place: written.place,
            kind: .clip(plan.kind),
            clock: plan.clock,
            instant: plan.instant,
            lengthScale: lengthScale
        )
        let isInOwnSpace = plan.space == .box || (plan.space == .media && picture != nil)
        let mask = try planner.masks(written.mask, takesClipArea: !isInOwnSpace)

        return FoundGeometry(
            area: area,
            points: vertices,
            position: position,
            cornerPin: cornerPin,
            crop: crop,
            mask: mask,
            isInOutputPixels: isInOutputPixels(of: plan.parent, time: time)
        )
    }

    // Whether a clip's space is output pixels: an unparented clip's and a solid's are, and a storyline clip's with a
    // corner pin gives its children output pixels. The chain is walked up past every shape placed by its geometry,
    // every adjustment and every clip with a corner pin, which gives its children the space its corner pin is written
    // in, and ParentFinder has ruled out a cycle, so it ends.
    private func isInOutputPixels(
        of parent: ClipParent?,
        time: TimePlan
    ) -> Bool {
        var parent = parent
        while case let .clip(index, _) = parent, time.clips[index].space == .parent || time.clips[index].isPinned {
            parent = time.clips[index].parent
        }

        switch parent {
        case .none:
            return true

        case let .storyline(index, _):
            return time.storyline[index].source.media == nil || time.sequence.storyline[index].cornerPin != nil

        case .clip:
            return false
        }
    }

    // A path's vertices as its entry holds them. A tracked path's vertex and tangents written without keyframes are
    // true on the track's frame.
    private func points(
        of plan: ClipPlan,
        found: [PathVertex<PropertyValue<GeometryPoint>, PropertyValue<Point>>]?,
        written: Clip
    ) -> [PathVertex<FollowedValue<GeometryPoint>, FollowedValue<Point>>]? {
        guard let found else { return nil }

        let isOnTrackFrame = plan.onTrackFrame(of: written).contains(.points)
        return found.map { vertex in
            vertex.map(
                vertex: { $0.followed(at: plan.instant, isOnTrackFrame: isOnTrackFrame) { $0 } },
                tangent: { $0.followed(at: plan.instant, isOnTrackFrame: isOnTrackFrame) { $0 } }
            )
        }
    }

    // A tracked clip's mask leaf written without keyframes is true on the track's frame.
    private func masks(
        of plan: ClipPlan,
        found: [FoundMask]?,
        written: Clip
    ) -> [ResolvedMask]? {
        guard let found else { return nil }

        let isOnTrackFrame = plan.onTrackFrame(of: written).contains(.mask)
        return found.map { found in
            guard isOnTrackFrame else { return found.mask }

            return found.mask.onTrackFrame { leaf in found.staticLeaves.contains(leaf) }
        }
    }

    private func shapePoints(of clip: Clip) -> PathProperty? {
        guard case let .shape(shape) = clip.content else { return nil }

        return shape.points
    }

    private func title(
        of plan: ClipPlan,
        written: Clip,
        scale: Double,
        time: TimePlan
    ) throws -> TitlePlan? {
        guard case let .title(title) = written.content else { return nil }

        let looks = ClipLookPlanner(
            place: written.place,
            kind: .clip(plan.kind),
            clock: plan.clock,
            instant: plan.instant,
            scale: scale,
            theme: time.theme
        )
        return try titles.plan(
            title,
            looks: looks,
            pack: time.pack,
            width: written.width,
            unit: plan.animation.units?.by,
            visible: plan.visible,
            theme: time.theme
        )
    }

    // A property whose keyframes all lie before or all after the range its clip shows in, or for the sequence's own
    // keyframes the sequence from 0 to its end, would only ever show one value. It is judged on the windows tracking
    // leaves.
    private func checkKeyframes(of time: TimePlan) throws {
        for plan in time.storyline {
            try checkKeyframes(plan.keyframes, visible: plan.drawn, place: plan.place, kind: .clip(plan.source.kind))
        }
        for plan in time.clips {
            try checkKeyframes(plan.keyframes, visible: plan.visible, place: plan.place, kind: .clip(plan.kind))
        }
        try checkKeyframes(
            time.sequence.keyframes,
            visible: TimeRange(start: 0, end: time.duration),
            place: time.sequence.place,
            kind: .sequence
        )
    }

    private func checkKeyframes(
        _ keyframes: [KeyframeInstant],
        visible: TimeRange,
        place: Place,
        kind: PlaceKind
    ) throws {
        let leaves = keyframes.flatMap(\.leaves).reduce(into: [Place]()) { leaves, leaf in
            guard !leaves.contains(leaf) else { return }

            leaves.append(leaf)
        }

        for leaf in leaves {
            let instants = keyframes.filter { $0.leaves.contains { $0.isLeaf(of: leaf) } }.map(\.at)
            let isBefore = instants.allSatisfy { $0 < visible.start }
            let isAfter = instants.allSatisfy { $0 >= visible.end }
            guard !isBefore, !isAfter else {
                throw ResolveError.keyframesOutsideVisibleRange(
                    place: place.appending(key: "keyframes"),
                    kind: kind,
                    leaf: leaf.description,
                    visible: visible
                )
            }
        }
    }
}
