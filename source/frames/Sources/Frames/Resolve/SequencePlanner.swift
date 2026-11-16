//
//  SequencePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans what resolve decides for one sequence before evaluation, from its time plan: the documents it nests, its
// format, the areas, positions and crops found in their pictures, tracking, the stop on keyframes outside the windows
// tracking leaves, its titles set, the side of every label, how each clip is drawn, and its sound.
struct SequencePlanner: Sendable {
    // MARK: - Property
    private let finder: GeometryFinder
    private let tracker: TrackPlanner
    private let text: ThemeTypesetter
    private let placer = LabelPlacer()
    private let pictures: PicturePlanner
    private let sound = SoundPlanner()
    private let filters: FilterResolver
    private let conformer = CropConformer()
    private let drawer = ShapeDrawer()

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
        let text = ThemeTypesetter(shaper: shaper, library: library)
        self.text = text
        self.pictures = PicturePlanner(ocr: ocr, presets: presets, text: text, library: library)
        self.filters = FilterResolver(presets: presets, library: library)
    }

    // MARK: - Public
    func plan(_ time: TimePlan) throws -> SequencePlan {
        // A compound clip's or a document's picture is its nested document's output, so the nested plans come first.
        let storylineNested = try time.storyline.map { plan in try plan.source.media.flatMap(nested) }
        let clipNested = try time.clips.map { plan in try plan.media.flatMap(nested) }
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

        let lengthScale = time.theme.lengthScale(at: format.size.width)
        let storyline = try time.storyline.indices.map { index in
            StorylineGeometry(
                crop: crops[index],
                track: tracked.storyline[index],
                nested: storylineNested[index],
                filter: try filter(
                    time.sequence.storyline[index].filter,
                    kind: time.storyline[index].source.kind,
                    media: time.sequence.storyline[index].media,
                    scale: lengthScale,
                    theme: time.theme,
                    defaults: time.defaults,
                    place: time.storyline[index].place.appending(key: "filter")
                ),
                color: time.sequence.storyline[index].solid.map(time.theme.color)
            )
        }
        let clips = try tracked.time.clips.indices.map { index in
            let title = try title(of: written[index], format: format, theme: time.theme)
            let box = try box(
                of: tracked.time.clips[index],
                written: written[index],
                position: found[index].position,
                crop: found[index].crop,
                title: title,
                nested: clipNested[index],
                format: format,
                theme: time.theme
            )
            return ClipGeometry(
                area: found[index].area,
                position: found[index].position,
                box: box,
                crop: found[index].crop,
                track: tracked.clips[index],
                title: title,
                label: try label(
                    of: tracked.time.clips[index],
                    written: written[index],
                    area: found[index].area,
                    track: tracked.clips[index],
                    time: tracked.time,
                    storyline: storyline,
                    format: format
                ),
                nested: clipNested[index],
                appearance: try appearance(
                    of: tracked.time.clips[index],
                    written: written[index],
                    media: try mediaAppearance(
                        of: tracked.time.clips[index],
                        written: written[index],
                        box: box,
                        crop: found[index].crop,
                        nested: clipNested[index],
                        scale: lengthScale,
                        theme: time.theme
                    ),
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
    private func nested(_ media: ResolvedMedia) throws -> DocumentPlan? {
        switch media.source {
        case .file:
            nil

        case let .sequence(nested):
            .sequence(try plan(nested))

        case let .picture(nested):
            .picture(try pictures.plan(nested, sequences: plan))
        }
    }

    // The content rect lies inside the output frame by the inset, and an inset that leaves none stops. The background is
    // the theme `background` unless the format gives one.
    private func format(
        of time: TimePlan,
        nested: [DocumentPlan?]
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

        return FormatPlan(
            size: size,
            content: content,
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
        nested: [DocumentPlan?]
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
        nested: DocumentPlan?,
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

    // A media file's picture is its probed size. A compound clip's or an image or layout document's is the output of
    // its nested document, which is drawn, not read.
    private func picture(
        of media: ResolvedMedia,
        kind: ClipKind,
        nested: DocumentPlan?,
        place: Place
    ) throws -> Picture {
        if let nested {
            return Picture(name: media.reference ?? place.description, source: .document, size: nested.size)
        }
        // Media without a nested plan is a file.
        guard case let .file(file) = media.source, let size = file.size else {
            let reference = media.reference ?? place.description
            throw ResolveError.soundAsPicture(place: place, kind: .clip(kind), reference: reference)
        }

        return Picture(name: media.reference ?? file.path, source: .mediaFile(file.path), size: size)
    }

    // What a sequence clip's area and an unparented clip's position are in.
    private func output(of format: FormatPlan) -> Picture {
        Picture(name: "output", source: .document, size: format.size)
    }

    private func crop(
        of plan: StorylinePlan,
        written: StorylineClip,
        nested: DocumentPlan?,
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
        nested: DocumentPlan?,
        time: TimePlan,
        storylineNested: [DocumentPlan?],
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
        return try self.text.layout(
            text,
            style: style,
            width: written.width ?? format.size.width - theme.placementPadding * scale * 2,
            theme: theme,
            scale: scale,
            place: written.place.appending(key: "title"),
            kind: ClipKind.title.label
        )
    }

    // A title's box is its text box, and a media clip's is set by `width` and `height`. The box goes where its position
    // puts its anchor point, or where its placement sets it: a title by default where its style places it, and media
    // in the centre. A shape or an adjustment is placed by its area, and an audio clip is not drawn, so they have none.
    private func box(
        of plan: ClipPlan,
        written: Clip,
        position: PropertyValue<Point>?,
        crop: PropertyValue<FoundArea>?,
        title: TextLayout?,
        nested: DocumentPlan?,
        format: FormatPlan,
        theme: MergedTheme
    ) throws -> ClipBox? {
        let size: Size
        let style: String?
        switch written.content {
        case let .title(_, name):
            size = title?.size ?? Size(width: 0, height: 0)
            style = name

        case .media:
            guard plan.kind != .media(.audio), let media = plan.media else { return nil }

            let picture = try self.picture(
                of: media,
                kind: plan.kind,
                nested: nested,
                place: written.place.appending(key: "media")
            )
            size = mediaSize(width: written.width, height: written.height, crop: crop, picture: picture.size)
            style = nil

        case .shape, .adjust:
            return nil
        }
        guard written.placement == nil || written.position == nil else {
            throw ResolveError.placementWithPosition(place: written.place, kind: .clip(plan.kind))
        }
        guard !plan.isParented || position != nil else {
            throw ResolveError.parentWithoutPosition(place: written.place, kind: .clip(plan.kind))
        }

        let bounds = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let placement = written.placement ?? style.flatMap(theme.placement(ofStyle:)) ?? "center"
        let anchor = bounds.point(named: written.anchor ?? (position == nil ? placement : "center"))
        let topLeft = { (point: Point) in Point(x: point.x - anchor.x, y: point.y - anchor.y) }
        let placed: PropertyValue<Point> = switch position {
        case let .value(point):
            .value(topLeft(point))

        case let .keyframes(keyframes):
            .keyframes(keyframes.map { keyframe in
                TimedValue(index: keyframe.index, at: keyframe.at, value: topLeft(keyframe.value), ease: keyframe.ease)
            })

        case .none:
            .value(self.placed(
                bounds,
                at: placement,
                offset: style.flatMap(theme.offset(ofStyle:)),
                format: format,
                theme: theme
            ))
        }

        return ClipBox(size: size, position: placed, anchor: anchor)
    }

    // Given one of `width` and `height`, the other follows the aspect ratio of the first crop, or of the picture when
    // there is no crop. Given neither, the box is that crop or picture at one media pixel to an output pixel.
    private func mediaSize(
        width: Double?,
        height: Double?,
        crop: PropertyValue<FoundArea>?,
        picture: Size
    ) -> Size {
        let first = crop.map { crop in
            let rectangle = self.first(of: crop).rectangle
            return Size(width: rectangle.width, height: rectangle.height)
        } ?? picture

        switch (width, height) {
        case let (.some(width), .some(height)):
            return Size(width: width, height: height)

        case let (.some(width), .none):
            return Size(width: width, height: width * first.height / first.width)

        case let (.none, .some(height)):
            return Size(width: height * first.width / first.height, height: height)

        case (.none, .none):
            return first
        }
    }

    // The value a property takes first: its static value, or its earliest keyframe, the first written of those at one
    // instant. A property read with keyframes has at least one.
    private func first<Value>(of property: PropertyValue<Value>) -> Value {
        switch property {
        case let .value(value):
            value

        case let .keyframes(keyframes):
            keyframes.dropFirst().reduce(keyframes[0]) { first, keyframe in keyframe.at < first.at ? keyframe : first }
                .value
        }
    }

    // The top left of a box placed by name inside the output frame, inset by the placement padding on the edges the
    // name sits on, or on the top or bottom edge by a style's `offset`. A box in the middle of an axis is centred on
    // the whole frame, which the even insets leave the same.
    private func placed(
        _ box: Rectangle,
        at name: String,
        offset: Double?,
        format: FormatPlan,
        theme: MergedTheme
    ) -> Point {
        let scale = theme.lengthScale(at: format.size.width)
        let padding = theme.placementPadding * scale
        let edge = offset.map { $0 * scale } ?? padding
        let size = format.size
        let x = name.hasSuffix("left")
            ? padding
            : name.hasSuffix("right") ? size.width - padding - box.width : (size.width - box.width) / 2
        let y = name.hasPrefix("top")
            ? edge
            : name.hasPrefix("bottom") ? size.height - edge - box.height : (size.height - box.height) / 2

        return Point(x: x, y: y)
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

        let text = try self.text.layout(
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

    // A property not written takes its plain value, and keyframes move to sequence time on the clip's clock. A shape
    // takes the theme's colour for it unless it gives one, and its theme lengths in output pixels, which stay so under a
    // zoom.
    private func appearance(
        of plan: ClipPlan,
        written: Clip,
        media mediaAppearance: MediaAppearance?,
        scale: Double,
        theme: MergedTheme,
        defaults: ThemeDefaults
    ) throws -> ClipAppearance {
        let property = { (value: PropertyValue<Double>?, plain: Double) -> PropertyValue<Double> in
            switch value {
            case .none:
                .value(plain)

            case let .value(value):
                .value(value)

            case let .keyframes(keyframes):
                .keyframes(keyframes.map { keyframe in
                    TimedValue(
                        index: keyframe.index,
                        at: plan.clock.sequenceTime(ofClipTime: keyframe.at),
                        value: keyframe.value,
                        ease: keyframe.ease
                    )
                })
            }
        }
        let shape: ShapeDrawing? = switch written.content {
        case let .shape(shape):
            drawer.drawing(
                of: shape,
                color: written.color.map(theme.color) ?? theme.shapeColor(of: shape.kind),
                scale: scale,
                theme: theme
            )

        case .media, .title, .adjust:
            nil
        }

        return ClipAppearance(
            opacity: property(written.opacity, 1),
            scale: property(written.scale, 1),
            rotation: property(written.rotation, 0),
            blend: written.blend ?? "normal",
            shape: shape,
            filter: try filter(
                written.filter,
                kind: plan.kind,
                media: media(of: written),
                scale: scale,
                theme: theme,
                defaults: defaults,
                place: written.place.appending(key: written.content == .adjust ? "adjust" : "filter")
            ),
            media: mediaAppearance
        )
    }

    // A media clip's crops conform to its box by its `conform`, `fit` unless written, and without a crop its whole
    // picture does, so the box holds still while the crop moves. A border takes the theme's width, and a shadow is the
    // theme's, their lengths scaled.
    private func mediaAppearance(
        of plan: ClipPlan,
        written: Clip,
        box: ClipBox?,
        crop: PropertyValue<FoundArea>?,
        nested: DocumentPlan?,
        scale: Double,
        theme: MergedTheme
    ) throws -> MediaAppearance? {
        guard let box, case .media = written.content, let media = plan.media else { return nil }

        let conform = written.conform ?? .fit
        let bounds = Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
        let conformed = { (rectangle: Rectangle) in conformer.conformed(rectangle, to: bounds, by: conform) }
        let crops: PropertyValue<Rectangle>
        switch crop {
        case let .value(area):
            crops = .value(conformed(area.rectangle))

        case let .keyframes(keyframes):
            crops = .keyframes(keyframes.map { keyframe in
                TimedValue(
                    index: keyframe.index,
                    at: keyframe.at,
                    value: conformed(keyframe.value.rectangle),
                    ease: keyframe.ease
                )
            })

        case .none:
            let picture = try self.picture(
                of: media,
                kind: plan.kind,
                nested: nested,
                place: written.place.appending(key: "media")
            )
            crops = .value(conformed(picture.bounds))
        }
        let shadow = MediaShadow(
            radius: theme.shadowRadius * scale,
            offset: Point(x: theme.shadowOffset.x * scale, y: theme.shadowOffset.y * scale),
            color: theme.shadowColor
        )

        return MediaAppearance(
            conform: conform,
            crop: crops,
            radius: written.radius ?? 0,
            border: written.border.map { MediaBorder(width: theme.borderWidth * scale, color: theme.color($0)) },
            shadow: written.shadow ? shadow : nil
        )
    }

    // Drawn media takes the theme's filter when it writes none, except a compound clip or a template instance, whose
    // clips already took theirs. Nothing else takes a filter it does not write, and audio is drawn by nothing.
    private func takesDefaultFilter(
        _ kind: ClipKind,
        media: ClipMedia?
    ) -> Bool {
        guard case .media = kind, kind != .media(.sequence), kind != .media(.audio), let media else { return false }

        return !isTemplate(media.source)
    }

    private func isTemplate(_ source: MediaSource) -> Bool {
        switch source {
        case .template:
            true

        case let .argument(source, _):
            isTemplate(source)

        case .file, .imageSequence, .compound, .picture:
            false
        }
    }

    private func media(of clip: Clip) -> ClipMedia? {
        guard case let .media(media) = clip.content else { return nil }

        return media
    }

    // A clip applies the filter it writes, or the theme's default when it takes one, and otherwise none. `place` is
    // where the clip's choice is written, and the default's stops name the theme.
    private func filter(
        _ written: JSONValue?,
        kind: ClipKind,
        media: ClipMedia?,
        scale: Double,
        theme: MergedTheme,
        defaults: ThemeDefaults,
        place: Place
    ) throws -> [FilterOperation] {
        let operations: [FilterOperation]
        if let written {
            operations = try filters.operations(of: written, theme: theme, place: place, kind: .clip(kind))
        } else if takesDefaultFilter(kind, media: media) {
            operations = try filters.operations(of: defaults.filter, theme: theme)
        } else {
            operations = []
        }

        return operations.map { $0.scaled(by: scale) }
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
