//
//  ClipAppearancePlanner.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Plans where a clip is placed and how it is drawn: a title's, a media clip's or a box shape's box and where its
// placement or position puts it, how a media clip's picture fills that box, a storyline clip's box and transform, how
// a shape is drawn with its style, and the filter a clip applies, the theme's default included.
struct ClipAppearancePlanner: Sendable {
    // MARK: - Property
    private let filters: FilterResolver
    private let conformer = CropConformer()

    // MARK: - Initializer
    init(
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.filters = FilterResolver(presets: presets, library: library)
    }

    // MARK: - Public
    // A title's box is its text box, a media clip's is set by `width` and `height`, and a box shape's is its `width`
    // and `height` at the clip's instant, as written: its outset grows only the outline it draws. The box goes where its position puts its anchor point,
    // or where its placement sets it: a title by default where its style places it, and media and shapes in the
    // centre. Under content fit there is no frame to place on, so a placement stops and a box without a position has
    // its top left at the origin. A shape placed by its geometry or an adjustment has none, and an audio clip is not
    // drawn.
    func box(
        of plan: ClipPlan,
        written: Clip,
        position: PropertyValue<Point>?,
        crop: PropertyValue<FoundArea>?,
        title: TextLayout?,
        picture: Picture?,
        shape: ShapeAppearance?,
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
                frame: format.isMeasured ? nil : format.size
            )
            style = nil

        case .shape:
            guard case let .box(width, height, _) = shape?.geometry else { return nil }

            size = Size(width: value(of: width, at: plan.instant), height: value(of: height, at: plan.instant))
            style = nil

        case .adjust:
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
        let bounds = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        if format.isMeasured {
            guard written.placement == nil else {
                throw ResolveError.placementUnderContentFit(place: written.place, kind: .clip(plan.kind))
            }

            let anchor = bounds.point(named: written.anchor ?? "center")
            let placed = position.map { topLeft(of: $0, anchor: anchor) } ?? .value(Point(x: 0, y: 0))
            return ClipBox(size: size, position: placed, anchor: anchor)
        }

        // A title takes its style's placement by default, so a style that gives none leaves it no place.
        let named = written.placement ?? style.flatMap(theme.placement(ofStyle:))
        guard style == nil || named != nil || position != nil else {
            throw ResolveError.titleWithoutPlacement(place: written.place, kind: .clip(plan.kind), style: style ?? "")
        }

        let placement = named ?? "center"
        let anchor = bounds.point(named: written.anchor ?? (position == nil ? placement : "center"))
        let placed = position.map { topLeft(of: $0, anchor: anchor) } ?? .value(self.placed(
            bounds,
            at: placement,
            offset: style.flatMap(theme.offset(ofStyle:)),
            format: format,
            theme: theme
        ))

        return ClipBox(size: size, position: placed, anchor: anchor)
    }

    // How a shape clip is drawn (FRAMES-11), nil for any other clip. Its geometry is checked first: a rect or an
    // ellipse takes `area` or both of `width` and `height`, a path takes `points`, and every `points` keyframe holds
    // as many points. Keys written on the clip win over its style's, each whole, and without a style nothing but colour
    // names comes from the theme. Theme lengths come out in output pixels, so they stay under a parent's zoom, and a
    // stroke takes the `accent` colour, round joins, butt caps and no arrowheads unless written. A shape with neither a
    // fill nor a stroke after its style stops.
    func shape(
        of plan: ClipPlan,
        written: Clip,
        scale: Double,
        theme: MergedTheme
    ) throws -> ShapeAppearance? {
        guard case let .shape(shape) = written.content else { return nil }

        let kind = PlaceKind.clip(plan.kind)
        try checkGeometry(of: shape, written: written, kind: kind)

        try checkColors(of: shape, written: written, kind: kind, theme: theme)
        let style = try self.style(named: shape.style, written: written, kind: kind, theme: theme)
        let fill = shape.fill ?? style["fill"].flatMap(FillForm.init(value:))
        let stroke = shape.stroke ?? style["stroke"].flatMap(StrokeForm.init(value:))
        let shadow = shape.shadow ?? style["shadow"].flatMap(ShadowForm.init(value:))
        let fillColor: Color? = if case let .color(color) = fill { theme.color(color) } else { nil }
        let pathStroke = stroke.flatMap { self.stroke($0, scale: scale, theme: theme) }
        guard fillColor != nil || pathStroke != nil else {
            throw ResolveError.shapeDrawsNothing(place: written.place, kind: kind)
        }

        let outset = (shape.outset ?? style["outset"]?.numberValue ?? 0) * scale
        let geometry: ShapeGeometryPlan = if shape.isPlacedByBox, let width = shape.width, let height = shape.height {
            .box(
                width: property(width, plain: 0, clock: plan.clock),
                height: property(height, plain: 0, clock: plan.clock),
                outset: outset
            )
        } else if shape.kind == .path {
            .points(isClosed: shape.isClosed, anchor: written.anchor)
        } else {
            .area(outset: outset, anchor: written.anchor)
        }
        let radius = shape.radius.map { property($0, plain: 0, clock: plan.clock) }
            ?? .value(style["radius"]?.numberValue ?? 0)

        return ShapeAppearance(
            kind: shape.kind,
            geometry: geometry,
            radius: radius.map { $0 * scale },
            trim: shape.trim.map { property($0, plain: .whole, clock: plan.clock) } ?? .value(.whole),
            fill: fillColor,
            stroke: pathStroke,
            shadow: shadow.flatMap { self.shadow($0, scale: scale, theme: theme) }
        )
    }

    // A property not written takes its plain value, and keyframes move to sequence time on the clip's clock. A shape
    // comes planned by `shape(of:written:scale:theme:)`.
    func appearance(
        of plan: ClipPlan,
        written: Clip,
        box: ClipBox?,
        crop: PropertyValue<FoundArea>?,
        picture: Picture?,
        shape: ShapeAppearance?,
        scale: Double,
        theme: MergedTheme,
        defaults: ThemeDefaults
    ) throws -> ClipAppearance {
        ClipAppearance(
            opacity: property(written.opacity, plain: 1, clock: plan.clock),
            scale: property(written.scale, plain: 1, clock: plan.clock),
            rotation: property(written.rotation, plain: 0, clock: plan.clock),
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
                kind: plan.kind,
                box: box,
                crop: crop,
                picture: picture,
                scale: scale,
                theme: theme
            )
        )
    }

    // A storyline clip's box is `box`, which its conformed crop fills, and its anchor point, `center` unless written,
    // goes to its position. That is the centre of the frame unless written, so a clip that writes none of its
    // transform fills the frame exactly, and under content fit the box's top left lies at the origin. Its radius,
    // border and shadow are drawn as a media clip's. A solid has no box, and takes no transform (FRAMES-9), so it keeps
    // the plain values and its transform is the identity, as its children's space is output pixels (FRAMES-10).
    func appearance(
        of plan: StorylinePlan,
        written: StorylineClip,
        position: PropertyValue<Point>?,
        box: Size?,
        format: FormatPlan,
        scale: Double,
        theme: MergedTheme
    ) throws -> StorylineAppearance {
        guard let box else {
            return StorylineAppearance(
                box: nil,
                opacity: .value(1),
                scale: .value(1),
                rotation: .value(0),
                blend: "normal",
                radius: 0,
                border: nil,
                shadow: nil
            )
        }

        try checkColor(of: written.shadow, place: written.place, kind: plan.source.kind.label, theme: theme)
        try checkColor(of: written.border, place: written.place, kind: plan.source.kind.label, theme: theme)
        let bounds = Rectangle(x: 0, y: 0, width: box.width, height: box.height)
        let anchor = bounds.point(named: written.anchor ?? "center")
        let placed = position.map { topLeft(of: $0, anchor: anchor) }
            ?? .value(format.isMeasured ? Point(x: 0, y: 0) : topLeft(of: format.frame.center, anchor: anchor))

        return StorylineAppearance(
            box: ClipBox(size: box, position: placed, anchor: anchor),
            opacity: property(written.opacity, plain: 1, clock: plan.map),
            scale: property(written.scale, plain: 1, clock: plan.map),
            rotation: property(written.rotation, plain: 0, clock: plan.map),
            blend: written.blend ?? "normal",
            radius: (written.radius ?? 0) * scale,
            border: border(written.border, scale: scale, theme: theme),
            shadow: written.shadow.flatMap { shadow($0, scale: scale, theme: theme) }
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
    // there is no crop. Given neither, that crop or picture fits the output frame, or is its own pixel size when there
    // is no frame yet.
    private func mediaSize(
        width: Double?,
        height: Double?,
        crop: PropertyValue<FoundArea>?,
        picture: Size,
        frame: Size?
    ) -> Size {
        let first = crop.map { crop in
            let rectangle = crop.firstValue.rectangle
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
            guard let frame else { return first }
            guard frame.width / first.width > frame.height / first.height else {
                return Size(width: frame.width, height: first.height * frame.width / first.width)
            }

            return Size(width: first.width * frame.height / first.height, height: frame.height)
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
    // picture does, so the box holds still while the crop moves. Its radius, border and shadow lengths are theme
    // lengths, scaled.
    private func mediaAppearance(
        of written: Clip,
        kind: ClipKind,
        box: ClipBox?,
        crop: PropertyValue<FoundArea>?,
        picture: Picture?,
        scale: Double,
        theme: MergedTheme
    ) throws -> MediaAppearance? {
        guard let box, case .media = written.content, let picture else { return nil }

        try checkColor(of: written.shadow, place: written.place, kind: PlaceKind.clip(kind).label, theme: theme)
        try checkColor(of: written.border, place: written.place, kind: PlaceKind.clip(kind).label, theme: theme)
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

        return MediaAppearance(
            conform: conform,
            crop: crops,
            radius: (written.radius ?? 0) * scale,
            border: border(written.border, scale: scale, theme: theme),
            shadow: written.shadow.flatMap { shadow($0, scale: scale, theme: theme) }
        )
    }

    // Where a box's top left goes when its anchor point goes to each position.
    private func topLeft(
        of position: PropertyValue<Point>,
        anchor: Point
    ) -> PropertyValue<Point> {
        position.map { point in topLeft(of: point, anchor: anchor) }
    }

    private func topLeft(
        of point: Point,
        anchor: Point
    ) -> Point {
        Point(x: point.x - anchor.x, y: point.y - anchor.y)
    }

    // A property not written takes its plain value, and keyframes move from the clip's clock to sequence time.
    private func property<Value>(
        _ value: PropertyValue<Value>?,
        plain: Value,
        clock: TimeMap
    ) -> PropertyValue<Value> {
        value?.inSequenceTime(on: clock) ?? .value(plain)
    }

    // The value of a property in sequence time at an instant, as its resolved keyframes give it.
    private func value(
        of property: PropertyValue<Double>,
        at instant: Double
    ) -> Double {
        property.keyframes(at: instant) { $0 }.value(at: instant)
    }

    // A rect or an ellipse takes exactly one of `area` and the pair `width` and `height`, and only with the pair a
    // `placement`, and a path its points, every keyframe of them as many.
    private func checkGeometry(
        of shape: ClipShape,
        written: Clip,
        kind: PlaceKind
    ) throws {
        guard shape.kind != .path else {
            guard let points = shape.points else {
                throw ResolveError.missingKey(place: written.place, kind: kind, key: "points")
            }
            guard case let .keyframes(keyframes) = points else { return }

            let counts = keyframes.map(\.value.count)
            guard let other = keyframes.first(where: { $0.value.count != counts[0] }) else { return }

            throw ResolveError.pointCountsDiffer(
                place: written.place.appending(key: "keyframes").appending(index: other.index).appending(key: "points"),
                kind: kind,
                counts: [counts[0], other.value.count]
            )
        }

        switch (written.area, shape.width, shape.height) {
        case (.some, .none, .none):
            // `placement` places a clip by its box, and a shape given by its area is placed by its geometry.
            guard written.placement == nil else {
                throw ResolveError.placementWithoutBox(place: written.place, kind: kind)
            }

        case (.none, .some, .some):
            return

        case (.some, _, _):
            throw ResolveError.shapeAreaWithBox(place: written.place, kind: kind)

        case (.none, .none, .none):
            throw ResolveError.shapeWithoutGeometry(place: written.place, kind: kind)

        case (.none, .some, .none):
            throw ResolveError.missingKey(place: written.place, kind: kind, key: "height")

        case (.none, .none, .some):
            throw ResolveError.missingKey(place: written.place, kind: kind, key: "width")
        }
    }

    // A colour name written on a shape must be a theme colour. Those of its style were checked with the theme.
    private func checkColors(
        of shape: ClipShape,
        written: Clip,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws {
        var names: [(name: String, place: Place)] = []
        if case let .color(color) = shape.fill {
            names.append((color, written.place.appending(key: "fill")))
        }
        if case let .stroke(.some(color), _, _, _, _, _) = shape.stroke {
            names.append((color, written.place.appending(key: "stroke").appending(key: "color")))
        }
        for (name, place) in names where !theme.isColor(name) {
            throw ThemeError.unknownColor(place: place, kind: kind.label, name: name)
        }
        try checkColor(of: shape.shadow, place: written.place, kind: kind.label, theme: theme)
    }

    // A colour name a clip writes in its `shadow` must be a theme colour.
    private func checkColor(
        of shadow: ShadowForm?,
        place: Place,
        kind: String,
        theme: MergedTheme
    ) throws {
        guard case let .shadow(_, _, .some(color)) = shadow, !theme.isColor(color) else { return }

        throw ThemeError.unknownColor(
            place: place.appending(key: "shadow").appending(key: "color"),
            kind: kind,
            name: color
        )
    }

    // A colour name a clip writes as its `border` must be a theme colour.
    private func checkColor(
        of border: BorderForm?,
        place: Place,
        kind: String,
        theme: MergedTheme
    ) throws {
        guard case let .color(color) = border, !theme.isColor(color) else { return }

        throw ThemeError.unknownColor(place: place.appending(key: "border"), kind: kind, name: color)
    }

    // The shape style a shape names, its lengths in points, or nothing without a name. A name the theme does not
    // hold stops, listing the styles it holds.
    private func style(
        named name: String?,
        written: Clip,
        kind: PlaceKind,
        theme: MergedTheme
    ) throws -> JSONObject {
        guard let name else { return JSONObject() }
        guard let style = theme.shapeStyle(named: name) else {
            throw ThemeError.unknownShapeStyle(
                place: written.place.appending(key: "style"),
                kind: kind.label,
                name: name,
                styles: theme.shapeStyleNames
            )
        }

        return style
    }

    private func stroke(
        _ form: StrokeForm,
        scale: Double,
        theme: MergedTheme
    ) -> PathStroke? {
        guard case let .stroke(color, width, join, cap, start, end) = form else { return nil }

        return PathStroke(
            width: width * scale,
            color: theme.color(color ?? "accent"),
            join: join ?? .round,
            cap: cap ?? .butt,
            start: start ?? .none,
            end: end ?? .none
        )
    }

    // A shadow takes what it leaves out from the theme `shadow`, its lengths scaled.
    private func shadow(
        _ form: ShadowForm,
        scale: Double,
        theme: MergedTheme
    ) -> DropShadow? {
        guard case let .shadow(radius, offset, color) = form else { return nil }

        let moved = offset ?? theme.shadowOffset
        return DropShadow(
            radius: (radius ?? theme.shadowRadius) * scale,
            offset: Point(x: moved.x * scale, y: moved.y * scale),
            color: color.map(theme.color) ?? theme.shadowColor
        )
    }

    // A border takes the theme's width, and its colour unless the clip writes one, its width scaled.
    private func border(
        _ border: BorderForm?,
        scale: Double,
        theme: MergedTheme
    ) -> MediaBorder? {
        border.map { border in
            MediaBorder(width: theme.borderWidth * scale, color: borderColor(of: border, theme: theme))
        }
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
