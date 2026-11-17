//
//  ClipAppearancePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans where a connected or sequence clip is placed and how it is drawn: a title's or a media clip's box and where
// its placement or position puts it, how a media clip's picture fills that box, how a shape is drawn, and the filter a
// clip applies, the theme's default included.
struct ClipAppearancePlanner: Sendable {
    // MARK: - Property
    private let filters: FilterResolver
    private let conformer = CropConformer()
    private let drawer = ShapeDrawer()

    // MARK: - Initializer
    init(
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.filters = FilterResolver(presets: presets, library: library)
    }

    // MARK: - Public
    // A title's box is its text box, and a media clip's is set by `width` and `height`. The box goes where its position
    // puts its anchor point, or where its placement sets it: a title by default where its style places it, and media
    // in the centre. A shape or an adjustment is placed by its area, and an audio clip is not drawn, so they have none.
    func box(
        of plan: ClipPlan,
        written: Clip,
        position: PropertyValue<Point>?,
        crop: PropertyValue<FoundArea>?,
        title: TextLayout?,
        picture: Picture?,
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
            guard let picture else { return nil }

            size = mediaSize(
                width: written.width,
                height: written.height,
                crop: crop,
                picture: picture.size,
                frame: format.size
            )
            style = nil

        case .shape, .adjust:
            return nil
        }
        guard written.placement == nil || written.position == nil else {
            throw ResolveError.placementWithPosition(place: written.place, kind: .clip(plan.kind))
        }
        guard plan.parent == nil || written.placement == nil else {
            throw ResolveError.parentWithPlacement(place: written.place, kind: .clip(plan.kind))
        }
        guard plan.parent == nil || position != nil else {
            throw ResolveError.parentWithoutPosition(place: written.place, kind: .clip(plan.kind))
        }

        // A title takes its style's placement by default, so a style that gives none leaves it no place.
        let named = written.placement ?? style.flatMap(theme.placement(ofStyle:))
        guard style == nil || named != nil || position != nil else {
            throw ResolveError.titleWithoutPlacement(place: written.place, kind: .clip(plan.kind), style: style ?? "")
        }

        let bounds = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        let placement = named ?? "center"
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

    // A property not written takes its plain value, and keyframes move to sequence time on the clip's clock. A shape
    // takes the theme's colour for it unless it gives one, and its theme lengths in output pixels, which stay so under a
    // zoom.
    func appearance(
        of plan: ClipPlan,
        written: Clip,
        box: ClipBox?,
        crop: PropertyValue<FoundArea>?,
        picture: Picture?,
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
            media: try mediaAppearance(
                of: written,
                box: box,
                crop: crop,
                picture: picture,
                scale: scale,
                theme: theme
            )
        )
    }

    // A clip applies the filter it writes, or the theme's default when it takes one, and otherwise none. `place` is
    // where the clip's choice is written, and the default's stops name the theme.
    func filter(
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

    // MARK: - Private
    // Given one of `width` and `height`, the other follows the aspect ratio of the first crop, or of the picture when
    // there is no crop. Given neither, that crop or picture fits the output frame.
    private func mediaSize(
        width: Double?,
        height: Double?,
        crop: PropertyValue<FoundArea>?,
        picture: Size,
        frame: Size
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
            guard frame.width / first.width > frame.height / first.height else {
                return Size(width: frame.width, height: first.height * frame.width / first.width)
            }

            return Size(width: first.width * frame.height / first.height, height: frame.height)
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

    // A media clip's crops conform to its box by its `conform`, `fit` unless written, and without a crop its whole
    // picture does, so the box holds still while the crop moves. A border takes the theme's width, and its colour unless
    // the clip writes one, and a shadow is the theme's, their lengths scaled.
    private func mediaAppearance(
        of written: Clip,
        box: ClipBox?,
        crop: PropertyValue<FoundArea>?,
        picture: Picture?,
        scale: Double,
        theme: MergedTheme
    ) throws -> MediaAppearance? {
        guard let box, case .media = written.content, let picture else { return nil }

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
            border: written.border.map { border in
                MediaBorder(width: theme.borderWidth * scale, color: borderColor(of: border, theme: theme))
            },
            shadow: written.shadow ? shadow : nil
        )
    }

    private func borderColor(
        of border: BorderForm,
        theme: MergedTheme
    ) -> Color {
        switch border {
        case .theme:
            theme.borderColor

        case let .color(written):
            theme.color(written)
        }
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

        case .file, .imageSequence, .compound:
            false
        }
    }

    private func media(of clip: Clip) -> ClipMedia? {
        guard case let .media(media) = clip.content else { return nil }

        return media
    }
}
