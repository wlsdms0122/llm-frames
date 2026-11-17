//
//  SequencePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what resolve decides for one sequence before evaluation, from its time plan: the documents it nests, its
// format, the areas, positions and crops found in their pictures, tracking, the stop on keyframes outside the windows
// tracking leaves, what was found under a shape or adjustment brought into its space, its titles set, where each clip
// is placed and how it is drawn, and its sound.
struct SequencePlanner: Sendable {
    // MARK: - Property
    private let finder: GeometryFinder
    private let tracker: TrackPlanner
    private let text: ThemeTypesetter
    private let sound = SoundPlanner()
    private let appearances: ClipAppearancePlanner

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
        let format = try self.format(of: time, nested: storylineNested)
        let written = time.sequence.storyline.flatMap(\.connected) + time.sequence.clips
        let clipPictures = try time.clips.indices.map { index in
            try picture(
                of: time.clips[index],
                nested: clipNested[index],
                place: written[index].place.appending(key: "media")
            )
        }

        let crops = try time.storyline.indices.map { index in
            try crop(
                of: time.storyline[index],
                written: time.sequence.storyline[index],
                nested: storylineNested[index],
                format: format,
                theme: time.theme
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
                format: format,
                theme: time.theme
            )
        }

        let tracked = try tracker.plan(time, crops: crops, areas: found.map(\.area))
        try checkKeyframes(of: tracked.time)
        // A tracked clip is parented to a storyline clip, so no text it finds needs a track, and what was found under a
        // shape or adjustment is brought into its space once every track is planned.
        let parentSpace = ParentSpacePlanner(tracked: tracked, areas: found.map(\.area))
        let placed = time.clips.indices.map { index in
            let plan = time.clips[index]
            return (
                area: parentSpace.area(found[index].area, written: written[index].area, of: plan),
                position: parentSpace.position(found[index].position, written: written[index].position, of: plan),
                crop: found[index].crop
            )
        }

        let lengthScale = time.theme.lengthScale(at: format.size.width)
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
                appearance: appearances.appearance(
                    of: time.storyline[index],
                    written: time.sequence.storyline[index],
                    position: storylinePositions[index],
                    format: format,
                    scale: lengthScale,
                    theme: time.theme
                )
            )
        }
        let clips = try tracked.time.clips.indices.map { index in
            let title = try title(of: written[index], format: format, theme: time.theme)
            let box = try appearances.box(
                of: tracked.time.clips[index],
                written: written[index],
                position: placed[index].position,
                crop: placed[index].crop,
                title: title,
                picture: clipPictures[index],
                format: format,
                theme: time.theme
            )
            return ClipGeometry(
                area: placed[index].area,
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

        return SequencePlan(time: tracked.time, format: format, storyline: storyline, clips: clips, sound: sound)
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

    // The background is the theme `background` unless the format gives one.
    private func format(
        of time: TimePlan,
        nested: [SequencePlan?]
    ) throws -> FormatPlan {
        let format = time.sequence.format
        let size = try format.size ?? defaultSize(of: time, nested: nested)

        return FormatPlan(
            size: size,
            conform: format.conform ?? .fit,
            background: time.theme.color(format.background ?? "background"),
            fps: time.fps,
            duration: time.duration
        )
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

    // A solid fills the frame, so its picture is the frame's size.
    private func picture(
        of plan: StorylinePlan,
        nested: SequencePlan?,
        format: FormatPlan
    ) throws -> Picture {
        guard let media = plan.source.media else {
            return Picture(
                name: ClipKind.solid.label,
                source: .solid,
                size: format.size
            )
        }

        return try picture(of: media, kind: plan.source.kind, nested: nested, place: plan.place.appending(key: "media"))
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

    // What an unparented clip's area and position are in.
    private func output(of format: FormatPlan) -> Picture {
        Picture(name: "output", source: .document, size: format.size)
    }

    private func crop(
        of plan: StorylinePlan,
        written: StorylineClip,
        nested: SequencePlan?,
        format: FormatPlan,
        theme: MergedTheme
    ) throws -> PropertyValue<FoundArea>? {
        guard let crop = written.crop else { return nil }

        let picture = try self.picture(of: plan, nested: nested, format: format)
        return try finder.crops(
            crop,
            in: picture,
            pictureClock: .storyline(plan),
            clock: plan.map,
            instant: plan.instant,
            padding: theme.cropPadding * theme.lengthScale(at: picture.size.width),
            place: written.place,
            kind: plan.source.kind.label
        )
    }

    // A storyline clip has no parent, so its position is in output pixels and a text form stops.
    private func position(
        of plan: StorylinePlan,
        written: StorylineClip,
        format: FormatPlan,
        theme: MergedTheme
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
            padding: theme.areaPadding * theme.lengthScale(at: space.size.width),
            place: written.place,
            kind: plan.source.kind.label
        )
    }

    // A parented clip's area and position are in its parent's space, and an unparented clip's in output pixels, as are
    // those of a clip under a chain of shapes and adjustments that reaches no other parent. A text form is searched in
    // the parent's picture, the media of a storyline or media clip, at the media time the parent's clock gives, and
    // under a shape or adjustment what it finds is where it lies in that media until `ParentSpacePlanner` brings it into
    // the parent's space. A media clip's crop is in its own picture.
    private func geometry(
        of plan: ClipPlan,
        written: Clip,
        picture: Picture?,
        time: TimePlan,
        storylineNested: [SequencePlan?],
        clipPictures: [Picture?],
        format: FormatPlan
    ) throws -> (area: PropertyValue<FoundArea>?, position: PropertyValue<Point>?, crop: PropertyValue<FoundArea>?) {
        let theme = time.theme
        let parent = try plan.parent.flatMap { parent in
            try space(of: parent, time: time, storylineNested: storylineNested, clipPictures: clipPictures, format: format)
        }
        let space = parent?.picture ?? output(of: format)
        let spaceClock = parent?.clock ?? .still

        let area = try written.area.map { area in
            if parent == nil, let text = byText(area, place: written.place) {
                throw ResolveError.textAreaInOutputPixels(place: text, kind: .clip(plan.kind))
            }

            return try finder.areas(
                area,
                key: "area",
                in: space,
                pictureClock: spaceClock,
                clock: plan.clock,
                instant: plan.instant,
                padding: theme.areaPadding * theme.lengthScale(at: space.size.width),
                place: written.place,
                kind: plan.kind.label
            )
        }
        let position = try written.position.map { position in
            if parent == nil, let text = byText(position, place: written.place) {
                throw ResolveError.textAreaInOutputPixels(place: text, kind: .clip(plan.kind))
            }

            return try finder.positions(
                position,
                in: space,
                pictureClock: spaceClock,
                clock: plan.clock,
                instant: plan.instant,
                padding: theme.areaPadding * theme.lengthScale(at: space.size.width),
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
                    padding: theme.cropPadding * theme.lengthScale(at: picture.size.width),
                    place: written.place,
                    kind: plan.kind.label
                )
            }
        }

        return (area, position, crop)
    }

    // The picture a parent's space is searched in, and how sequence time becomes its media time: a storyline clip's
    // media or a solid's frame, a media clip's media, a title's text box as a space with no picture, and for a shape
    // or adjustment the space its geometry is written in, its own parent's. Nil is output pixels, the space of a shape
    // or adjustment without a parent.
    private func space(
        of parent: ClipParent,
        time: TimePlan,
        storylineNested: [SequencePlan?],
        clipPictures: [Picture?],
        format: FormatPlan
    ) throws -> (picture: Picture, clock: PictureClock)? {
        switch parent {
        case let .storyline(index, _):
            let plan = time.storyline[index]
            return (try picture(of: plan, nested: storylineNested[index], format: format), .storyline(plan))

        case let .clip(index, id):
            let plan = time.clips[index]
            if let picture = clipPictures[index] {
                return (picture, plan.timing.map { .media($0) } ?? .still)
            }

            switch plan.kind {
            case .shape, .adjust:
                // ParentFinder has ruled out a cycle, so the chain ends.
                return try plan.parent.flatMap { parent in
                    try space(
                        of: parent,
                        time: time,
                        storylineNested: storylineNested,
                        clipPictures: clipPictures,
                        format: format
                    )
                }

            default:
                return (Picture(name: id, source: .space, size: format.size), .still)
            }
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

    // A title wraps at its `width`, by default the output width less the placement padding on each side.
    private func title(
        of written: Clip,
        format: FormatPlan,
        theme: MergedTheme
    ) throws -> TextLayout? {
        guard case let .title(text, style) = written.content else { return nil }

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
