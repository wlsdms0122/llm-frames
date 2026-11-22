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
        ocr: any OCRProvider,
        languages: [LanguageTag]?,
        tracker: any TrackerProvider,
        shaper: any ShapingProvider,
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.finder = GeometryFinder(ocr: ocr, languages: languages)
        self.tracker = TrackPlanner(tracker: tracker, ocr: ocr, languages: languages)
        self.titles = TitlePlanner(shaper: shaper, library: library)
        self.sound = SoundPlanner(presets: presets)
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
            try mask(
                of: time.storyline[index],
                written: time.sequence.storyline[index],
                nested: storylineNested[index],
                lengthScale: lengthScale
            )
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
                storylineNested: storylineNested,
                clipPictures: clipPictures,
                format: format,
                lengthScale: lengthScale
            )
        }

        let storylinePositions = try time.storyline.indices.map { index in
            try position(
                of: time.storyline[index],
                written: time.sequence.storyline[index],
                format: format
            )
        }
        let storylineCornerPins = try time.storyline.indices.map { index in
            try cornerPin(
                of: time.storyline[index],
                written: time.sequence.storyline[index],
                format: format
            )
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
        // Text a tracked clip finds lies in the media it follows, where it is at the value's own time, as evaluation
        // takes it, and what was found under a shape or adjustment is brought into its space once every track and
        // shape is planned.
        let parentSpace = try ParentSpacePlanner(
            tracked: tracked,
            written: written,
            shapes: shapes,
            areas: found.map(\.area),
            points: found.map(\.points),
            positions: found.map(\.position),
            cornerPins: found.map(\.cornerPin),
            masks: found.map(\.mask)
        )
        let placed = try time.clips.indices.map { index in
            (
                area: try parentSpace.area(of: index),
                points: try parentSpace.points(of: index),
                position: try parentSpace.position(of: index),
                cornerPin: try parentSpace.cornerPin(of: index),
                crop: found[index].crop,
                mask: try parentSpace.mask(of: index)
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
        crops: [PropertyValue<FoundArea>?]
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
        crop: PropertyValue<FoundArea>?,
        nested: SequencePlan?,
        format: FormatPlan
    ) throws -> Size? {
        guard plan.source.media != nil else { return nil }
        guard format.isMeasured else { return format.size }

        return try pictureBox(of: plan, crop: crop, nested: nested)
    }

    // A storyline clip's crop fills its box by the format's `conform`.
    private func checkCrop(
        _ crop: PropertyValue<FoundArea>?,
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
        crop: PropertyValue<FoundArea>?,
        nested: SequencePlan?
    ) throws -> Size? {
        guard let media = plan.source.media else { return nil }

        if let first = crop?.firstValue.rectangle {
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
            return Picture(name: media.reference ?? place.description, source: .document, size: nested.format.size)
        }
        // Media without a nested plan is a file.
        guard case let .file(file) = media.source, let size = file.size else {
            let reference = media.reference ?? place.description
            throw ResolveError.soundAsPicture(place: place, kind: .clip(kind), reference: reference)
        }

        return Picture(
            name: media.reference ?? file.path,
            source: .mediaFile(file),
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

    // What the areas and positions written in output pixels are in, an unparented clip's and a solid's children's: the
    // output frame, or under content fit the measuring space, which has no edges until it is measured.
    private func output(of format: FormatPlan) -> Picture {
        Picture(name: "output", source: format.isMeasured ? .space : .document, size: format.size)
    }

    // A solid takes no crop.
    private func crop(
        of plan: StorylinePlan,
        written: StorylineClip,
        nested: SequencePlan?
    ) throws -> PropertyValue<FoundArea>? {
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
            pictureClock: written.track?.clock(of: .crop, on: .storyline(plan)) ?? .storyline(plan),
            clock: plan.map,
            instant: plan.instant,
            place: written.place,
            kind: plan.source.kind.label
        )
    }

    // A storyline clip's mask is in the media pixels of its own media, found there as its crop is. A solid takes none.
    // A tracked clip's mask written without keyframes is true on the track's frame, but a leaf a text form found other
    // than the track's target.
    private func mask(
        of plan: StorylinePlan,
        written: StorylineClip,
        nested: SequencePlan?,
        lengthScale: Double
    ) throws -> [ResolvedMask]? {
        guard let mask = written.mask, let media = plan.source.media else { return nil }

        let picture = try self.picture(
            of: media,
            kind: plan.source.kind,
            nested: nested,
            place: plan.place.appending(key: "media")
        )
        let planner = MaskPlanner(
            finder: finder,
            place: written.place,
            kind: .clip(plan.source.kind),
            clock: plan.map,
            instant: plan.instant,
            lengthScale: lengthScale
        )
        let pictureClock = written.track?.clock(of: .mask, on: .storyline(plan)) ?? .storyline(plan)
        return try planner.masks(mask, in: picture, pictureClock: pictureClock)?
            .map { found in
                guard let target = written.track else { return found.mask }

                return found.mask.onTrackFrame { leaf in
                    found.staticLeaves.contains(leaf)
                        && target.isOnTrackFrame(.mask, isFoundByText: found.textTimes[leaf] != nil)
                }
            }
    }

    // A storyline clip has no parent, so its position is in output pixels and a text form stops.
    private func position(
        of plan: StorylinePlan,
        written: StorylineClip,
        format: FormatPlan
    ) throws -> PropertyValue<Point>? {
        guard let position = written.position else { return nil }

        if let text = byText(position, place: written.place) {
            throw ResolveError.textAreaInOutputPixels(place: text, kind: .clip(plan.source.kind))
        }
        let space = output(of: format)
        // ClipAreaFinder has stopped a clip area on a storyline clip.
        return try finder.positions(
            position,
            in: space,
            pictureClock: .still,
            clock: plan.map,
            instant: plan.instant,
            lengthScale: 1,
            place: written.place,
            kind: plan.source.kind.label
        ).map(\.fixed)
    }

    // A storyline clip has no parent, so its corner pin is in output pixels, where a text form stops, and it has no
    // parent's media to track, so `track` stops beside it (FRAMES-12).
    private func cornerPin(
        of plan: StorylinePlan,
        written: StorylineClip,
        format: FormatPlan
    ) throws -> PropertyValue<[GeometryPoint]>? {
        guard let cornerPin = written.cornerPin else { return nil }

        if let text = byText(cornerPin, key: "cornerPin", place: written.place) {
            throw ResolveError.textAreaInOutputPixels(place: text, kind: .clip(plan.source.kind))
        }
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
            in: output(of: format),
            pictureClock: .still,
            clock: plan.map,
            instant: plan.instant,
            lengthScale: 1,
            place: written.place,
            kind: plan.source.kind.label
        )
    }

    // A parented clip's area and position are in its parent's space, and an unparented clip's in output pixels, as are
    // those of a clip parented to a solid or under a chain of shapes and adjustments that reaches neither a storyline
    // picture nor a clip with a box. A text form is searched in the parent's picture, the media of a storyline or media
    // clip, at the media time the parent's clock gives, and under a shape or adjustment what it finds is where it lies
    // in that media until `ParentSpacePlanner` brings it into the parent's space. A media clip's crop is in its own
    // picture. A mask is in the clip's own coordinate space: a media clip's media, a title's or a box shape's box,
    // which has no picture to search, and for a shape placed by its geometry or an adjustment the space its parent
    // gives, searched as its area is. A followed value that the clip's track searches on the track's frame is searched
    // on the frame its `time` names.
    private func geometry(
        of plan: ClipPlan,
        written: Clip,
        picture: Picture?,
        time: TimePlan,
        storylineNested: [SequencePlan?],
        clipPictures: [Picture?],
        format: FormatPlan,
        lengthScale: Double
    ) throws -> FoundGeometry {
        let space = try self.space(
            of: plan.parent,
            time: time,
            storylineNested: storylineNested,
            clipPictures: clipPictures,
            format: format
        )

        let area = try written.area.map { area in
            if space.isOutputPixels, let text = byText(area, place: written.place) {
                throw ResolveError.textAreaInOutputPixels(place: text, kind: .clip(plan.kind))
            }

            return try finder.areas(
                area,
                key: "area",
                in: space.picture,
                pictureClock: plan.clock(of: .area, on: space.clock, track: written.track),
                clock: plan.clock,
                instant: plan.instant,
                lengthScale: lengthScale,
                place: written.place,
                kind: plan.kind.label
            )
        }
        let points = { (points: PropertyValue<[PositionForm]>, value: FollowedKey, key: String) in
            if space.isOutputPixels, let text = byText(points, key: key, place: written.place) {
                throw ResolveError.textAreaInOutputPixels(place: text, kind: .clip(plan.kind))
            }

            return try finder.points(
                points,
                key: key,
                in: space.picture,
                pictureClock: plan.clock(of: value, on: space.clock, track: written.track),
                clock: plan.clock,
                instant: plan.instant,
                lengthScale: lengthScale,
                place: written.place,
                kind: plan.kind.label
            )
        }
        let position = try written.position.map { position in
            if space.isOutputPixels, let text = byText(position, place: written.place) {
                throw ResolveError.textAreaInOutputPixels(place: text, kind: .clip(plan.kind))
            }

            return try finder.positions(
                position,
                in: space.picture,
                pictureClock: plan.clock(of: .position, on: space.clock, track: written.track),
                clock: plan.clock,
                instant: plan.instant,
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
                    pictureClock: plan.clock(of: .crop, on: plan.mediaClock.map { .media($0) } ?? .still, track: written.track),
                    clock: plan.clock,
                    instant: plan.instant,
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
        let mask: [FoundMask]?
        if plan.space == .media, let picture {
            mask = try planner.masks(
                written.mask,
                in: picture,
                pictureClock: plan.clock(of: .mask, on: plan.mediaClock.map { .media($0) } ?? .still, track: written.track)
            )
        } else if plan.space == .box {
            let box = Picture(name: plan.id ?? written.place.description, source: .space, size: format.size)
            mask = try planner.masks(written.mask, in: box, pictureClock: .still) { place in
                .textMaskInOwnBox(place: place, kind: .clip(plan.kind))
            }
        } else {
            mask = try planner.masks(
                written.mask,
                in: space.picture,
                pictureClock: plan.clock(of: .mask, on: space.clock, track: written.track),
                textStop: space.isOutputPixels ? { .textAreaInOutputPixels(place: $0, kind: .clip(plan.kind)) } : nil,
                takesClipArea: true
            )
        }

        return FoundGeometry(
            area: area,
            points: try shapePoints(of: written).map { try points($0, .points, "points") },
            position: position,
            cornerPin: try written.cornerPin.map { try points($0, .cornerPin, "cornerPin") },
            crop: crop,
            mask: mask,
            isInOutputPixels: space.isOutputPixels
        )
    }

    // The picture a clip's space is searched in, how sequence time becomes its media time, and whether that space is
    // output pixels: a storyline clip's media, a media clip's media, a title's text box as a space with no picture, and
    // for a shape or adjustment the space its geometry is written in, its own parent's. An unparented clip's space and
    // a solid's are output pixels. The chain is walked up past every shape placed by its geometry, every adjustment and
    // every clip with a corner pin, which gives its children the space its corner pin is written in, and ParentFinder
    // has ruled out a cycle, so it ends. A storyline clip with a corner pin gives its children output pixels.
    private func space(
        of parent: ClipParent?,
        time: TimePlan,
        storylineNested: [SequencePlan?],
        clipPictures: [Picture?],
        format: FormatPlan
    ) throws -> (picture: Picture, clock: PictureClock, isOutputPixels: Bool) {
        var parent = parent
        while case let .clip(index, _) = parent, time.clips[index].space == .parent || time.clips[index].isPinned {
            parent = time.clips[index].parent
        }

        switch parent {
        case .none:
            return (output(of: format), .still, true)

        case let .storyline(index, _):
            let plan = time.storyline[index]
            guard let media = plan.source.media, time.sequence.storyline[index].cornerPin == nil else {
                return (output(of: format), .storyline(plan), true)
            }

            let place = plan.place.appending(key: "media")
            let picture = try picture(of: media, kind: plan.source.kind, nested: storylineNested[index], place: place)
            return (picture, .storyline(plan), false)

        case let .clip(index, id):
            let plan = time.clips[index]
            guard let picture = clipPictures[index] else {
                return (Picture(name: id, source: .space, size: format.size), .still, false)
            }

            return (picture, plan.mediaClock.map { .media($0) } ?? .still, false)
        }
    }

    private func shapePoints(of clip: Clip) -> PropertyValue<[PositionForm]>? {
        guard case let .shape(shape) = clip.content else { return nil }

        return shape.points
    }

    // The place of the first point of the list under `key` given by an area written with text.
    private func byText(
        _ points: PropertyValue<[PositionForm]>,
        key: String,
        place: Place
    ) -> Place? {
        switch points {
        case let .value(forms):
            return forms.firstIndex(where: \.isFoundByText).map { place.appending(key: key).appending(index: $0) }

        case let .keyframes(keyframes):
            for keyframe in keyframes {
                guard let index = keyframe.value.firstIndex(where: \.isFoundByText) else { continue }

                return place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: key)
                    .appending(index: index)
            }
            return nil
        }
    }

    // The place of the first area written with text.
    private func byText(
        _ area: PropertyValue<AreaForm>,
        place: Place
    ) -> Place? {
        switch area {
        case let .value(form):
            return form.isFoundByText ? place.appending(key: "area") : nil

        case let .keyframes(keyframes):
            return keyframes.first { $0.value.isFoundByText }.map { keyframe in
                place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: "area")
            }
        }
    }

    // The place of the first position given by an area written with text.
    private func byText(
        _ position: PropertyValue<PositionForm>,
        place: Place
    ) -> Place? {
        switch position {
        case let .value(form):
            return form.isFoundByText ? place.appending(key: "position") : nil

        case let .keyframes(keyframes):
            return keyframes.first { $0.value.isFoundByText }.map { keyframe in
                place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: "position")
            }
        }
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
