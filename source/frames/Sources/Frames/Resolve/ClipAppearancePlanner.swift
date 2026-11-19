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
    private let cropChecker = CropChecker()
    private let choices = ClipChoiceMerger()
    // What a stroke takes where neither the clip nor its style gives it.
    private static let strokeDefaults = JSONValue.object(JSONObject(members: [
        JSONMember(key: "color", value: .string("accent")),
        JSONMember(key: "join", value: .string(StrokeJoin.round.rawValue)),
        JSONMember(key: "cap", value: .string(StrokeCap.butt.rawValue)),
        JSONMember(key: "start", value: .string(StrokeEnd.none.rawValue)),
        JSONMember(key: "end", value: .string(StrokeEnd.none.rawValue))
    ]))

    // MARK: - Initializer
    init(
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.filters = FilterResolver(presets: presets, library: library)
    }

    // MARK: - Public
    // A title's box is its text box, a media clip's is set by `width` and `height`, and a box shape's is its `width`
    // and `height` at the clip's instant, as written: its outset grows only the outline it draws. The box goes where
    // its position puts its anchor point, or where its placement sets it: a title by default where its style places it,
    // and media and shapes in the centre. Under content fit there is no frame to place on, so a placement stops and a
    // box without a position has its top left at the origin. A shape placed by its geometry or an adjustment has none,
    // and an audio clip is not drawn.
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

    // How a shape clip is drawn, nil for any other clip. Its geometry is checked first: a rect or an ellipse takes
    // `area` or both of `width` and `height`, a path takes `points`, and every `points` keyframe holds as many points.
    // Its `radius`, `outset`, `fill`, `stroke` and `shadow` are timed over its style's by `ClipLookPlanner`, and without
    // a style nothing but colour names and the theme `shadow` come from the theme. A shape with neither a fill nor a
    // stroke after its style stops.
    func shape(
        of plan: ClipPlan,
        written: Clip,
        scale: Double,
        theme: MergedTheme
    ) throws -> ShapeAppearance? {
        guard case let .shape(shape) = written.content else { return nil }

        let kind = PlaceKind.clip(plan.kind)
        try checkGeometry(of: shape, written: written, kind: kind)
        if let name = shape.style, theme.shapeStyle(named: name) == nil {
            throw ThemeError.unknownShapeStyle(
                place: written.place.appending(key: "style"),
                kind: kind.label,
                name: name,
                styles: theme.shapeStyleNames
            )
        }

        let looks = ClipLookPlanner(
            place: written.place,
            kind: kind,
            clock: plan.clock,
            instant: plan.instant,
            scale: scale,
            theme: theme
        )
        let timed = { (key: String, property: LookProperty?, structure: ValueStructure, defaults: JSONValue?) in
            try looks.timed(
                property,
                key: key,
                as: structure,
                style: shape.style.map { ["shapes", $0, key] },
                defaults: defaults
            )
        }
        let fill = try timed("fill", shape.fill, LookStructureTable.fill, nil)
        let stroke = try timed("stroke", shape.stroke, LookStructureTable.stroke, Self.strokeDefaults)
        let shadow = try timed("shadow", shape.shadow, LookStructureTable.shadow, theme.value(at: ["shadow"]))
        guard fill != .off || stroke != .off else {
            throw ResolveError.shapeDrawsNothing(place: written.place, kind: kind)
        }

        let outset = try timed("outset", shape.outset, LookStructureTable.length, nil)
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

        return ShapeAppearance(
            kind: shape.kind,
            geometry: geometry,
            radius: try timed("radius", shape.radius, LookStructureTable.length, nil),
            trim: shape.trim.map { property($0, plain: .whole, clock: plan.clock) } ?? .value(.whole),
            fill: fill,
            stroke: stroke,
            shadow: shadow
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
        theme: MergedTheme
    ) throws -> ClipAppearance {
        ClipAppearance(
            opacity: property(written.opacity, plain: 1, clock: plan.clock),
            scale: property(written.scale, plain: 1, clock: plan.clock),
            rotation: property(written.rotation, plain: 0, clock: plan.clock),
            blend: written.blend ?? "normal",
            shape: shape,
            filter: try filter(
                written.filter,
                key: plan.kind == .adjust ? "adjust" : "filter",
                of: written.place,
                kind: plan.kind,
                media: media(of: written),
                clock: plan.clock,
                instant: plan.instant,
                scale: scale,
                theme: theme
            ),
            media: try mediaAppearance(
                of: plan,
                written: written,
                box: box,
                crop: crop,
                picture: picture,
                scale: scale,
                theme: theme
            )
        )
    }

    // A storyline clip's box is `box`, which its conformed crop fills, and its anchor point, `center` unless written,
    // goes to its position. That is the centre of the frame unless written, so a clip that writes none of its transform
    // fills the frame exactly, and under content fit the box's top left lies at the origin. Its radius, border and
    // shadow are drawn as a media clip's. A solid has no box and takes no transform, so it keeps the plain values and
    // its transform is the identity, as its children's space is output pixels.
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
                radius: .off,
                border: .off,
                shadow: .off
            )
        }

        let looks = ClipLookPlanner(
            place: written.place,
            kind: .clip(plan.source.kind),
            clock: plan.map,
            instant: plan.instant,
            scale: scale,
            theme: theme
        )
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
            radius: try looks.timed(written.radius, key: "radius", as: LookStructureTable.length),
            border: try border(written.border, looks: looks, theme: theme),
            shadow: try shadow(written.shadow, looks: looks, theme: theme)
        )
    }

    // A clip applies the filter it writes merged over the theme's default when it takes one, the default when it
    // writes none, and otherwise none, so both are typed by `FilterResolver`. `key` is the clip's key for it on the
    // clip at `place`. The clip's stops name its choice, and the default's name the theme.
    func filter(
        _ property: LookProperty?,
        key: String,
        of place: Place,
        kind: ClipKind,
        media: ClipMedia?,
        clock: TimeMap,
        instant: Double,
        scale: Double,
        theme: MergedTheme
    ) throws -> TimedValue {
        let defaults = takesDefaultFilter(kind, media: media) ? ["defaults", "filter"] : nil
        let looks = ClipLookPlanner(
            place: place,
            kind: .clip(kind),
            clock: clock,
            instant: instant,
            scale: scale,
            theme: theme
        )
        guard let written = property?.written else {
            let layer = defaults.map { path in theme.place(of: path.reduce(Place.root) { $0.appending(key: $1) }) }
            return try filters.timed(
                property,
                merged: defaults.flatMap(theme.value(at:)),
                key: key,
                place: layer ?? place,
                looks: looks,
                theme: theme,
                kind: .themeDefaults
            )
        }

        let choicePlace = place.appending(key: key)
        let merged = try choices.merged(
            written,
            over: defaults,
            as: LookStructureTable.filter,
            place: choicePlace,
            kind: .clip(kind),
            theme: theme
        )
        return try filters.timed(
            property,
            merged: merged,
            key: key,
            place: choicePlace,
            looks: looks,
            theme: theme,
            kind: .clip(kind)
        )
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
    // the whole frame.
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
    // picture does, so the box holds still while the crop moves. Its radius, border and shadow are timed by
    // `ClipLookPlanner`.
    private func mediaAppearance(
        of plan: ClipPlan,
        written: Clip,
        box: ClipBox?,
        crop: PropertyValue<FoundArea>?,
        picture: Picture?,
        scale: Double,
        theme: MergedTheme
    ) throws -> MediaAppearance? {
        guard let box, case .media = written.content, let picture else { return nil }

        let conform = written.conform ?? .fit
        try cropChecker.check(
            crop,
            of: picture,
            box: box.size,
            conform: conform,
            isTracked: written.track != nil,
            place: written.place.appending(key: "crop"),
            kind: .clip(plan.kind)
        )
        let bounds = Rectangle(x: 0, y: 0, width: box.size.width, height: box.size.height)
        let conformed = { (rectangle: Rectangle) in conformer.conformed(rectangle, to: bounds, by: conform) }
        let crops: PropertyValue<Rectangle>
        switch crop {
        case let .value(area):
            crops = .value(conformed(area.rectangle))

        case let .keyframes(keyframes):
            crops = .keyframes(keyframes.map { keyframe in
                PropertyKeyframe(
                    index: keyframe.index,
                    at: keyframe.at,
                    value: conformed(keyframe.value.rectangle),
                    ease: keyframe.ease
                )
            })

        case .none:
            crops = .value(conformed(picture.bounds))
        }

        let looks = ClipLookPlanner(
            place: written.place,
            kind: .clip(plan.kind),
            clock: plan.clock,
            instant: plan.instant,
            scale: scale,
            theme: theme
        )

        return MediaAppearance(
            conform: conform,
            crop: crops,
            radius: try looks.timed(written.radius, key: "radius", as: LookStructureTable.length),
            border: try border(written.border, looks: looks, theme: theme),
            shadow: try shadow(written.shadow, looks: looks, theme: theme)
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

    // A box's border and shadow are drawn only where the clip asks, so the theme's values complete the clip's and do
    // not lie below it.
    private func border(
        _ property: LookProperty?,
        looks: ClipLookPlanner,
        theme: MergedTheme
    ) throws -> TimedValue {
        try looks.timed(property, key: "border", as: LookStructureTable.border, defaults: theme.value(at: ["border"]))
    }

    private func shadow(
        _ property: LookProperty?,
        looks: ClipLookPlanner,
        theme: MergedTheme
    ) throws -> TimedValue {
        try looks.timed(property, key: "shadow", as: LookStructureTable.shadow, defaults: theme.value(at: ["shadow"]))
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
