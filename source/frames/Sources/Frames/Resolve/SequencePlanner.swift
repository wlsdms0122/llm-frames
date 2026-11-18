//
//  SequencePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what resolve decides for one sequence before evaluation, from its time plan: the documents it nests, its
// format, the areas, positions and crops found in their pictures, tracking, the stop on keyframes outside the windows
// tracking leaves, what was found under a shape or adjustment brought into its space, its titles set, where each clip
// is placed and how it is drawn, and its sound. A content-fit sequence is planned in its measuring space on a frame the
// size of its first storyline picture's box, which gives its length scale, and then measured.
struct SequencePlanner: Sendable {
    // MARK: - Property
    private let finder: GeometryFinder
    private let tracker: TrackPlanner
    private let text: ThemeTypesetter
    private let sound = SoundPlanner()
    private let appearances: ClipAppearancePlanner
    private let contentFit = ContentFitPlanner()

    // MARK: - Initializer
    init(
        ocr: any OCRProvider,
        tracker: any TrackerProvider,
        shaper: any ShapingProvider,
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.finder = GeometryFinder(ocr: ocr)
        self.tracker = TrackPlanner(tracker: tracker, ocr: ocr)
        self.text = ThemeTypesetter(shaper: shaper, library: library)
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
                format: format
            )
        }

        let storylinePositions = try time.storyline.indices.map { index in
            try position(
                of: time.storyline[index],
                written: time.sequence.storyline[index],
                format: format
            )
        }

        let tracked = try tracker.plan(time, crops: crops, areas: found.map(\.area))
        try checkKeyframes(of: tracked.time)
        let lengthScale = time.theme.lengthScale(at: format.size.width)
        let shapes = try tracked.time.clips.indices.map { index in
            try appearances.shape(
                of: tracked.time.clips[index],
                written: written[index],
                scale: lengthScale,
                theme: time.theme
            )
        }
        // A tracked clip is parented to a storyline clip, so no text it finds needs a track, and what was found under a
        // shape or adjustment is brought into its space once every track and shape is planned.
        let parentSpace = ParentSpacePlanner(
            tracked: tracked,
            written: written,
            shapes: shapes,
            areas: found.map(\.area),
            points: found.map(\.points),
            positions: found.map(\.position)
        )
        let placed = time.clips.indices.map { index in
            (
                area: parentSpace.area(of: index),
                points: parentSpace.points(of: index),
                position: parentSpace.position(of: index),
                crop: found[index].crop
            )
        }

        let storyline = try time.storyline.indices.map { index in
            StorylineGeometry(
                crop: crops[index],
                track: tracked.storyline[index],
                nested: storylineNested[index],
                filter: try appearances.filter(
                    time.sequence.storyline[index].filter,
                    kind: time.storyline[index].source.kind,
                    media: time.sequence.storyline[index].media,
                    scale: lengthScale,
                    theme: time.theme,
                    defaults: time.defaults,
                    place: time.storyline[index].place.appending(key: "filter")
                ),
                color: time.sequence.storyline[index].solid.map(time.theme.color),
                appearance: try appearances.appearance(
                    of: time.storyline[index],
                    written: time.sequence.storyline[index],
                    position: storylinePositions[index],
                    box: try box(
                        of: time.storyline[index],
                        crop: crops[index],
                        nested: storylineNested[index],
                        format: format
                    ),
                    format: format,
                    scale: lengthScale,
                    theme: time.theme
                )
            )
        }
        let clips = try tracked.time.clips.indices.map { index in
            let title = try title(of: written[index], format: format, theme: time.theme)
            let shape = shapes[index]
            let box = try appearances.box(
                of: tracked.time.clips[index],
                written: written[index],
                position: placed[index].position,
                crop: placed[index].crop,
                title: title,
                picture: clipPictures[index],
                shape: shape,
                format: format,
                theme: time.theme
            )
            return ClipGeometry(
                area: placed[index].area,
                points: placed[index].points,
                position: placed[index].position,
                box: box,
                crop: placed[index].crop,
                track: tracked.clips[index],
                title: title,
                nested: clipNested[index],
                appearance: try appearances.appearance(
                    of: tracked.time.clips[index],
                    written: written[index],
                    box: box,
                    crop: placed[index].crop,
                    picture: clipPictures[index],
                    shape: shape,
                    scale: lengthScale,
                    theme: time.theme,
                    defaults: time.defaults
                )
            )
        }

        let sound = self.sound.sound(
            of: tracked.time,
            written: written,
            storylineNested: storylineNested,
            clipNested: clipNested
        )

        let plan = SequencePlan(time: tracked.time, format: format, storyline: storyline, clips: clips, sound: sound)
        guard let margin = format.margin else { return plan }

        return try contentFit.fitted(plan, margin: margin, inOutputPixels: found.map(\.isInOutputPixels))
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

        return Picture(name: media.reference ?? file.path, source: .mediaFile(file), size: size)
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
            pictureClock: .storyline(plan),
            clock: plan.map,
            instant: plan.instant,
            place: written.place,
            kind: plan.source.kind.label
        )
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
        return try finder.positions(
            position,
            in: space,
            pictureClock: .still,
            clock: plan.map,
            instant: plan.instant,
            place: written.place,
            kind: plan.source.kind.label
        )
    }

    // A parented clip's area and position are in its parent's space, and an unparented clip's in output pixels, as are
    // those of a clip parented to a solid or under a chain of shapes and adjustments that reaches neither a storyline
    // picture nor a clip with a box. A text form is searched in the parent's picture, the media of a storyline or media
    // clip, at the media time the parent's clock gives, and under a shape or adjustment what it finds is where it lies
    // in that media until `ParentSpacePlanner` brings it into the parent's space. A media clip's crop is in its own
    // picture.
    private func geometry(
        of plan: ClipPlan,
        written: Clip,
        picture: Picture?,
        time: TimePlan,
        storylineNested: [SequencePlan?],
        clipPictures: [Picture?],
        format: FormatPlan
    ) throws -> (
        area: PropertyValue<FoundArea>?,
        points: PropertyValue<[Point]>?,
        position: PropertyValue<Point>?,
        crop: PropertyValue<FoundArea>?,
        isInOutputPixels: Bool
    ) {
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
                pictureClock: space.clock,
                clock: plan.clock,
                instant: plan.instant,
                place: written.place,
                kind: plan.kind.label
            )
        }
        let points = try shapePoints(of: written).map { points in
            if space.isOutputPixels, let text = byText(points, place: written.place) {
                throw ResolveError.textAreaInOutputPixels(place: text, kind: .clip(plan.kind))
            }

            return try finder.points(
                points,
                in: space.picture,
                pictureClock: space.clock,
                clock: plan.clock,
                instant: plan.instant,
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
                pictureClock: space.clock,
                clock: plan.clock,
                instant: plan.instant,
                place: written.place,
                kind: plan.kind.label
            )
        }
        let crop = try written.crop.flatMap { crop in
            try picture.map { picture in
                try finder.crops(
                    crop,
                    in: picture,
                    pictureClock: plan.timing.map { .media($0) } ?? .still,
                    clock: plan.clock,
                    instant: plan.instant,
                    place: written.place,
                    kind: plan.kind.label
                )
            }
        }

        return (area, points, position, crop, space.isOutputPixels)
    }

    // The picture a clip's space is searched in, how sequence time becomes its media time, and whether that space is
    // output pixels (FRAMES-10): a storyline clip's media, a media clip's media, a title's text box as a space with no
    // picture, and for a shape or adjustment the space its geometry is written in, its own parent's. An unparented
    // clip's space and a solid's are output pixels.
    private func space(
        of parent: ClipParent?,
        time: TimePlan,
        storylineNested: [SequencePlan?],
        clipPictures: [Picture?],
        format: FormatPlan
    ) throws -> (picture: Picture, clock: PictureClock, isOutputPixels: Bool) {
        switch parent {
        case .none:
            return (output(of: format), .still, true)

        case let .storyline(index, _):
            let plan = time.storyline[index]
            guard let media = plan.source.media else { return (output(of: format), .storyline(plan), true) }

            let place = plan.place.appending(key: "media")
            let picture = try picture(of: media, kind: plan.source.kind, nested: storylineNested[index], place: place)
            return (picture, .storyline(plan), false)

        case let .clip(index, id):
            let plan = time.clips[index]
            if let picture = clipPictures[index] {
                return (picture, plan.timing.map { .media($0) } ?? .still, false)
            }

            let isPlacedByGeometry = if case let .shape(shape) = writtenClip(at: index, in: time).content {
                shape.width == nil
            } else {
                false
            }
            switch plan.kind {
            case .shape where isPlacedByGeometry, .adjust:
                // ParentFinder has ruled out a cycle, so the chain ends.
                return try space(
                    of: plan.parent,
                    time: time,
                    storylineNested: storylineNested,
                    clipPictures: clipPictures,
                    format: format
                )

            default:
                return (Picture(name: id, source: .space, size: format.size), .still, false)
            }
        }
    }

    // A clip in the time plan's order of clips.
    private func writtenClip(
        at index: Int,
        in time: TimePlan
    ) -> Clip {
        let connected = time.sequence.storyline.flatMap(\.connected)
        return index < connected.count ? connected[index] : time.sequence.clips[index - connected.count]
    }

    private func shapePoints(of clip: Clip) -> PropertyValue<[PositionForm]>? {
        guard case let .shape(shape) = clip.content else { return nil }

        return shape.points
    }

    // The place of the first point given by an area written with text, which only a parented clip takes.
    private func byText(
        _ points: PropertyValue<[PositionForm]>,
        place: Place
    ) -> Place? {
        switch points {
        case let .value(forms):
            return forms.firstIndex(where: \.isFoundByText).map { place.appending(key: "points").appending(index: $0) }

        case let .keyframes(keyframes):
            for keyframe in keyframes {
                guard let index = keyframe.value.firstIndex(where: \.isFoundByText) else { continue }

                return place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: "points")
                    .appending(index: index)
            }
            return nil
        }
    }

    // The place of the first area written with text, which only a parented clip takes.
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

    // The place of the first position given by an area written with text, which only a parented clip takes.
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

    // A title wraps at its `width`, by default the output width less the placement padding on each side, which a
    // content-fit frame does not have yet.
    private func title(
        of written: Clip,
        format: FormatPlan,
        theme: MergedTheme
    ) throws -> TextLayout? {
        guard case let .title(text, style) = written.content else { return nil }
        guard written.width != nil || !format.isMeasured else {
            throw ResolveError.titleWidthUnderContentFit(place: written.place, kind: .clip(.title))
        }

        let scale = theme.lengthScale(at: format.size.width)
        return try self.text.layout(
            text,
            style: style,
            stylePlace: written.place.appending(key: "style"),
            width: written.width ?? format.size.width - theme.placementPadding * scale * 2,
            theme: theme,
            scale: scale,
            place: written.place.appending(key: "title"),
            kind: ClipKind.title.label
        )
    }

    // A property whose keyframes all lie before or all after the range its clip shows in would only ever show one
    // value. It is judged on the windows tracking leaves, since what is visible is what counts.
    private func checkKeyframes(of time: TimePlan) throws {
        for plan in time.storyline {
            try checkKeyframes(plan.keyframes, visible: plan.drawn, place: plan.place, kind: plan.source.kind)
        }
        for plan in time.clips {
            try checkKeyframes(plan.keyframes, visible: plan.visible, place: plan.place, kind: plan.kind)
        }
    }

    private func checkKeyframes(
        _ keyframes: [KeyframeInstant],
        visible: TimeRange,
        place: Place,
        kind: ClipKind
    ) throws {
        let properties = keyframes.flatMap(\.properties).reduce(into: [String]()) { properties, property in
            guard !properties.contains(property) else { return }

            properties.append(property)
        }

        for property in properties {
            let instants = keyframes.filter { $0.properties.contains(property) }.map(\.at)
            let isBefore = instants.allSatisfy { $0 < visible.start }
            let isAfter = instants.allSatisfy { $0 >= visible.end }
            guard !isBefore, !isAfter else {
                throw ResolveError.keyframesOutsideVisibleRange(
                    place: place.appending(key: "keyframes"),
                    kind: .clip(kind),
                    property: property,
                    visible: visible
                )
            }
        }
    }
}
