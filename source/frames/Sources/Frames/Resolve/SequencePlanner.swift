//
//  SequencePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what resolve decides for one sequence before evaluation, from its time plan: the documents it nests, its
// format, the areas, positions and crops found in their pictures, tracking, the stop on keyframes outside the windows
// tracking leaves, its titles set, and the side of every label.
struct SequencePlanner: Sendable {
    // MARK: - Property
    private let finder: GeometryFinder
    private let tracker: TrackPlanner
    private let fonts: FontFinder
    private let typesetter: Typesetter
    private let placer = LabelPlacer()

    // MARK: - Initializer
    init(
        ocr: any OCRProvider,
        tracker: any TrackerProvider,
        shaper: any ShapingProvider,
        library: ReferenceLibrary
    ) {
        self.finder = GeometryFinder(ocr: ocr)
        self.tracker = TrackPlanner(tracker: tracker, ocr: ocr)
        self.fonts = FontFinder(shaper: shaper, library: library)
        self.typesetter = Typesetter(shaper: shaper)
    }

    // MARK: - Public
    func plan(_ time: TimePlan) throws -> SequencePlan {
        // A compound clip's picture is its nested document's output, so the nested plans come first.
        let storylineNested = try time.storyline.map { plan in try plan.source.media?.nested.map(self.plan) }
        let clipNested = try time.clips.map { plan in try plan.media?.nested.map(self.plan) }
        let format = try self.format(of: time, nested: storylineNested)
        let written = time.sequence.storyline.flatMap(\.connected) + time.sequence.clips

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
                nested: clipNested[index],
                time: time,
                storylineNested: storylineNested,
                format: format
            )
        }

        let tracked = try tracker.plan(time, crops: crops, areas: found.map(\.area))
        try checkKeyframes(of: tracked.time)

        let storyline = time.storyline.indices.map { index in
            StorylineGeometry(crop: crops[index], track: tracked.storyline[index], nested: storylineNested[index])
        }
        let clips = try tracked.time.clips.indices.map { index in
            ClipGeometry(
                area: found[index].area,
                position: found[index].position,
                crop: found[index].crop,
                track: tracked.clips[index],
                title: try title(of: written[index], format: format, theme: time.theme),
                label: try label(
                    of: tracked.time.clips[index],
                    written: written[index],
                    area: found[index].area,
                    track: tracked.clips[index],
                    time: tracked.time,
                    storyline: storyline,
                    format: format
                ),
                nested: clipNested[index]
            )
        }

        return SequencePlan(time: tracked.time, format: format, storyline: storyline, clips: clips)
    }

    // MARK: - Private
    // The content rect lies inside the output frame by the inset, and an inset that leaves none stops.
    private func format(
        of time: TimePlan,
        nested: [SequencePlan?]
    ) throws -> FormatPlan {
        let format = time.sequence.format
        let size = try format.size ?? defaultSize(of: time, nested: nested)
        let inset = format.inset ?? .zero
        let content = Rectangle(
            x: inset.left,
            y: inset.top,
            width: size.width - inset.left - inset.right,
            height: size.height - inset.top - inset.bottom
        )
        guard content.width > 0, content.height > 0 else {
            throw ResolveError.noContentRect(
                place: time.sequence.place.appending(key: "format").appending(key: "inset"),
                kind: .sequence,
                size: size
            )
        }

        return FormatPlan(size: size, content: content, conform: format.conform ?? .fit)
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

    // A solid fills the content rect, so its picture is that rect's size.
    private func picture(
        of plan: StorylinePlan,
        nested: SequencePlan?,
        format: FormatPlan
    ) throws -> Picture {
        guard let media = plan.source.media else {
            return Picture(
                name: ClipKind.solid.label,
                source: .solid,
                size: Size(width: format.content.width, height: format.content.height)
            )
        }

        return try picture(of: media, kind: plan.source.kind, nested: nested, place: plan.place.appending(key: "media"))
    }

    // A media file's picture is its probed size. A compound clip's is the output of its nested document, which is
    // drawn, not read. An image or layout document's is resolved later.
    private func picture(
        of media: ResolvedMedia,
        kind: ClipKind,
        nested: SequencePlan?,
        place: Place
    ) throws -> Picture {
        if let nested {
            return Picture(name: media.reference ?? place.description, source: .document, size: nested.format.size)
        }
        guard let file = media.file else {
            throw ResolveError.unresolvedDocumentPicture(place: place, kind: .clip(kind))
        }
        guard let size = media.size else {
            throw ResolveError.unprobedMedia(place: place, kind: .clip(kind), reference: media.reference ?? file)
        }

        return Picture(name: media.reference ?? file, source: .mediaFile(file), size: size)
    }

    // What a sequence clip's area and an unparented clip's position are in.
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

    // A parented clip's area and position are in its storyline clip's picture, and a sequence clip's area and an
    // unparented position in output pixels. A media clip's crop is in its own media.
    private func geometry(
        of plan: ClipPlan,
        written: Clip,
        nested: SequencePlan?,
        time: TimePlan,
        storylineNested: [SequencePlan?],
        format: FormatPlan
    ) throws -> (area: PropertyValue<FoundArea>?, position: PropertyValue<Point>?, crop: PropertyValue<FoundArea>?) {
        let theme = time.theme
        let owner = plan.isParented ? plan.storyline : nil
        let pictureClock = owner.map { PictureClock.storyline(time.storyline[$0]) } ?? .still
        let parent = { (index: Int) in
            try self.picture(of: time.storyline[index], nested: storylineNested[index], format: format)
        }

        let area = try written.area.map { area in
            let picture = try owner.map(parent) ?? output(of: format)
            return try finder.areas(
                area,
                key: "area",
                in: picture,
                pictureClock: pictureClock,
                clock: plan.clock,
                instant: plan.instant,
                padding: theme.areaPadding * theme.lengthScale(at: picture.size.width),
                place: written.place,
                kind: plan.kind.label
            )
        }
        let position = try written.position.map { position in
            let byArea = self.byArea(position, place: written.place)
            if let byArea, owner == nil {
                throw ResolveError.areaPositionWithoutParent(place: byArea, kind: .clip(plan.kind))
            }

            // Points need no picture, so a clip placed by points alone looks at none.
            let picture = try owner.flatMap { byArea == nil ? nil : try parent($0) } ?? output(of: format)
            return try finder.positions(
                position,
                in: picture,
                pictureClock: pictureClock,
                clock: plan.clock,
                instant: plan.instant,
                padding: theme.areaPadding * theme.lengthScale(at: picture.size.width),
                place: written.place,
                kind: plan.kind.label
            )
        }
        let crop = try written.crop.flatMap { crop in
            try plan.media.map { media in
                let picture = try self.picture(
                    of: media,
                    kind: plan.kind,
                    nested: nested,
                    place: written.place.appending(key: "media")
                )
                return try finder.crops(
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

    // The place of the first position given by an area, which only a parented clip takes.
    private func byArea(
        _ position: PropertyValue<PositionForm>,
        place: Place
    ) -> Place? {
        switch position {
        case let .value(form):
            return isArea(form) ? place.appending(key: "position") : nil

        case let .keyframes(keyframes):
            return keyframes.first { isArea($0.value) }.map { keyframe in
                place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: "position")
            }
        }
    }

    private func isArea(_ form: PositionForm) -> Bool {
        if case .area = form { true } else { false }
    }

    // A title wraps at its `width`, by default the output width less the placement padding on each side.
    private func title(
        of written: Clip,
        format: FormatPlan,
        theme: MergedTheme
    ) throws -> TextLayout? {
        guard case let .title(text, style) = written.content else { return nil }

        let scale = theme.lengthScale(at: format.size.width)
        return try layout(
            text,
            style: style,
            width: written.width ?? format.size.width - theme.placementPadding * scale * 2,
            theme: theme,
            scale: scale,
            place: written.place.appending(key: "title"),
            kind: ClipKind.title.label
        )
    }

    // A label is set on one line in the `label` style. A parented shape is measured through its storyline clip's
    // picture.
    private func label(
        of plan: ClipPlan,
        written: Clip,
        area: PropertyValue<FoundArea>?,
        track: Track?,
        time: TimePlan,
        storyline: [StorylineGeometry],
        format: FormatPlan
    ) throws -> LabelPlan? {
        guard let label = written.label else { return nil }

        let text = try layout(
            label,
            style: "label",
            width: nil,
            theme: time.theme,
            scale: time.theme.lengthScale(at: format.size.width),
            place: written.place.appending(key: "label"),
            kind: plan.kind.label
        )
        let parent = try plan.storyline.flatMap { index -> ParentPicture? in
            guard plan.isParented, area != nil else { return nil }

            let owner = time.storyline[index]
            return ParentPicture(
                plan: owner,
                geometry: storyline[index],
                picture: try picture(of: owner, nested: storyline[index].nested, format: format)
            )
        }

        return try placer.label(
            text,
            of: plan,
            written: written,
            area: area,
            track: track,
            parent: parent,
            storyline: time.storyline,
            format: format,
            theme: time.theme
        )
    }

    // Lengths in a style are multiplied by the length scale of the place the text is drawn.
    private func layout(
        _ text: String,
        style name: String,
        width: Double?,
        theme: MergedTheme,
        scale: Double,
        place: Place,
        kind: String
    ) throws -> TextLayout {
        let style = theme.style(named: name, scale: scale)
        let face = try fonts.face(for: style, place: theme.fontPlace)

        return try typesetter.layout(text, style: style, face: face, width: width, place: place, kind: kind)
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
