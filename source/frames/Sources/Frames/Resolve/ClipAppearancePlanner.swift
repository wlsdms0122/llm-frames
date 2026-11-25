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
    private let heads: StrokeHeadResolver
    // What a stroke takes where neither the clip nor its style gives it.
    private static let strokeDefaults = JSONValue.object(JSONObject(members: [
        JSONMember(key: "color", value: .string("accent")),
        JSONMember(key: "align", value: .string(StrokeAlign.center.rawValue)),
        JSONMember(key: "join", value: .string(StrokeJoin.round.rawValue)),
        JSONMember(key: "cap", value: .string(StrokeCap.butt.rawValue)),
        JSONMember(key: "start", value: .string(StrokeHeadResolver.none)),
        JSONMember(key: "end", value: .string(StrokeHeadResolver.none)),
        JSONMember(key: "dashOffset", value: .number(0))
    ]))

    // MARK: - Initializer
    init(
        presets: any PresetProvider,
        library: ReferenceLibrary
    ) {
        self.filters = FilterResolver(presets: presets, library: library)
        self.heads = StrokeHeadResolver(presets: presets)
    }

    // MARK: - Public
    // Each keyframe of a tracked corner pin is brought back through the inverse of the track's homography at its own
    // time, on the frame shown there or the nearest frame followed, corner by corner as `Track.broughtBack` brings it
    // back for evaluation, and a corner at or beyond that inverse's horizon, or a corner pin of points brought back that
    // is not strictly convex, stops (FRAMES-27 A tracked corner pin). A corner of a clip area is on the track's frame
    // already and is kept. A static corner pin true on the track's frame is where the homography is the identity; one a
    // text form found other than the track's target is one keyframe at the clip's instant, and is brought back there as
    // a keyframe is (FRAMES-19 Timed values).
    private func checkBroughtBack(
        of points: PropertyValue<GeometryQuad>,
        written: PropertyValue<[PositionForm]>,
        track: TrackedMedia,
        isOnTrackFrame: Bool,
        instant: Double,
        place: Place,
        kind: PlaceKind
    ) throws {
        switch (points, written) {
        case let (.keyframes(keyframes), .keyframes(writtenKeyframes)):
            for keyframe in keyframes where !isBroughtBack(keyframe.value, track: track, at: keyframe.at) {
                throw ResolveError.cornerPinNotBroughtBack(
                    place: place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: "cornerPin"),
                    kind: kind,
                    time: writtenKeyframes.first { $0.index == keyframe.index }?.at ?? keyframe.at
                )
            }

        case let (.value(points), .value):
            guard !isOnTrackFrame, !isBroughtBack(points, track: track, at: instant) else { return }

            throw ResolveError.cornerPinNotBroughtBack(place: place.appending(key: "cornerPin"), kind: kind, time: nil)

        default:
            return
        }
    }

    // Whether a corner pin at the time comes back to the track's frame, as evaluation brings it back.
    private func isBroughtBack(
        _ points: GeometryQuad,
        track: TrackedMedia,
        at time: Double
    ) -> Bool {
        track.track.broughtBack(points, atMediaTime: track.clock.mediaTime(atSequenceTime: time)) != nil
    }

    // A title's box is its text box, a media clip's is set by `width` and `height`, and a box shape's is its `width`
    // and `height` at the clip's instant, as written: its outset grows only the outline it draws. The box goes where
    // its position puts its anchor point, or where its placement sets it: a title by default where its style places it,
    // with its style's offset, and media and shapes in the centre. A content-fit frame is not measured yet, so a box
    // placed by its placement is placed on it once it is, and the centre is no default there: a box with neither a
    // position nor a placement has its top left at the origin. A shape placed by its geometry or an adjustment has
    // none, and an audio clip is not drawn. A clip with a corner pin has none either: its corner pin places its box.
    func box(
        of plan: ClipPlan,
        written: Clip,
        position: PropertyValue<GeometryPoint>?,
        crop: PropertyValue<FoundArea>?,
        title: TextLayout?,
        picture: Picture?,
        shape: ShapeAppearance?,
        format: FormatPlan,
        theme: MergedTheme
    ) throws -> ClipBox? {
        guard
            written.cornerPin == nil,
            let size = boxSize(of: plan, written: written, crop: crop, title: title, picture: picture, shape: shape, format: format)
        else {
            return nil
        }

        let style: String? = if case let .title(title) = written.content { title.style } else { nil }
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
        if let position {
            return ClipBox(size: size, position: position, anchor: bounds.point(named: written.anchor ?? "center"))
        }

        // A title takes its style's placement by default, so on a frame of a written size a style that gives none
        // leaves it no place.
        let named = written.placement ?? style.flatMap(theme.placement(ofStyle:))
        guard format.isMeasured || style == nil || named != nil else {
            throw ResolveError.titleWithoutPlacement(place: written.place, kind: .clip(plan.kind), style: style ?? "")
        }
        guard let name = named ?? (format.isMeasured ? nil : "center") else {
            let anchor = bounds.point(named: written.anchor ?? "center")
            return ClipBox(size: size, position: .value(.point(anchor)), anchor: anchor)
        }

        let scale = theme.lengthScale(at: format.size.width)
        let padding = theme.placementPadding * scale
        let placement = BoxPlacement(
            name: name,
            padding: padding,
            edge: style.flatMap(theme.offset(ofStyle:)).map { $0 * scale } ?? padding
        )
        let anchor = bounds.point(named: written.anchor ?? name)
        let placed = placement.position(of: size, anchor: anchor, in: format.frame)

        return ClipBox(size: size, position: .value(.point(placed)), anchor: anchor, placement: placement)
    }

    // The box a clip with a corner pin draws, sized as every clip's box is, and the points its corners go to, nil for a
    // clip without one. It takes no other placement, a style's included, so a key that places a clip stops beside it,
    // and a rect or ellipse placed by its area stops, its outline being in its space already; a path takes no
    // `cornerPin` key, which the key table refuses. Every corner pin written or found as numbers is strictly convex (FRAMES-27).
    func cornerPin(
        of plan: ClipPlan,
        written: Clip,
        points: PropertyValue<[GeometryPoint]>?,
        track: TrackedMedia?,
        crop: PropertyValue<FoundArea>?,
        title: TextLayout?,
        picture: Picture?,
        shape: ShapeAppearance?,
        format: FormatPlan
    ) throws -> ClipCornerPin? {
        guard let pin = written.cornerPin, let points = points?.map(GeometryQuad.init(corners:)) else { return nil }

        let kind = PlaceKind.clip(plan.kind)
        let isPlacedByBox = if case .box = shape?.geometry { true } else { false }
        guard shape == nil || isPlacedByBox else {
            throw ResolveError.cornerPinOnGeometry(place: place(of: pin, key: "cornerPin", at: written.place), kind: kind)
        }
        let key = placementKey(
            at: written.place,
            placement: written.placement,
            position: written.position,
            anchor: written.anchor,
            scale: written.scale,
            rotation: written.rotation
        )
        if let (place, key) = key {
            throw ResolveError.cornerPinWithPlacement(place: place, kind: kind, key: key)
        }
        try checkConvexity(of: points, written: pin, place: written.place, kind: kind)
        if let track {
            try checkBroughtBack(
                of: points,
                written: pin,
                track: track,
                isOnTrackFrame: plan.onTrackFrame(of: written).contains(.cornerPin),
                instant: plan.instant,
                place: written.place,
                kind: kind
            )
        }
        guard
            let size = boxSize(of: plan, written: written, crop: crop, title: title, picture: picture, shape: shape, format: format)
        else {
            return nil
        }

        return ClipCornerPin(size: size, points: points)
    }

    // How a shape clip is drawn, nil for any other clip. Its geometry is checked first: a rect or an ellipse takes
    // `area` or both of `width` and `height`, a path takes `points`, and every `points` value holds as many vertices.
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
        let stroke = try heads.pinned(
            timed("stroke", shape.stroke, LookStructureTable.stroke, Self.strokeDefaults),
            place: written.place.appending(key: "stroke"),
            kind: kind
        )
        let shadow = try timed("shadow", shape.shadow, LookStructureTable.shadow, theme.value(at: ["shadow"]))
        guard fill != .off || stroke != .off else {
            throw ResolveError.shapeDrawsNothing(place: written.place, kind: kind)
        }
        try checkAlign(of: stroke, shape: shape, written: written, kind: kind)

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
            radius: try timed("radius", shape.radius, LookStructureTable.radius, nil),
            trim: shape.trim.map { property($0, plain: .whole, clock: plan.clock) } ?? .value(.whole),
            fill: fill,
            stroke: stroke,
            shadow: shadow
        )
    }

    // A property not written takes its plain value, and keyframes move to sequence time on the clip's clock. A shape
    // comes planned by `shape(of:written:scale:theme:)`. `box` is the size of the box a media clip's picture fills,
    // placed by its position or by its corner pin.
    func appearance(
        of plan: ClipPlan,
        written: Clip,
        box: Size?,
        crop: PropertyValue<FoundArea>?,
        picture: Picture?,
        shape: ShapeAppearance?,
        scale: Double,
        theme: MergedTheme
    ) throws -> ClipAppearance {
        ClipAppearance(
            opacity: property(written.opacity, plain: 1, clock: plan.clock),
            scale: property(written.scale, plain: .identity, clock: plan.clock),
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
    // its transform is the identity, as its children's space is output pixels. A clip with a corner pin, `cornerPin`
    // its points in output pixels, has its box placed by it and no other placement, so a key that places it otherwise
    // stops beside it, and keeps the plain scale and rotation (FRAMES-27).
    func appearance(
        of plan: StorylinePlan,
        written: StorylineClip,
        position: PropertyValue<Point>?,
        cornerPin: PropertyValue<[GeometryPoint]>?,
        box: Size?,
        format: FormatPlan,
        scale: Double,
        theme: MergedTheme
    ) throws -> StorylineAppearance {
        guard let box else {
            return StorylineAppearance(
                box: nil,
                opacity: .value(1),
                scale: .value(.identity),
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
        let kind = PlaceKind.clip(plan.source.kind)
        let pinned: ClipCornerPin?
        if let cornerPin = cornerPin?.map(GeometryQuad.init(corners:)), let pin = written.cornerPin {
            let key = placementKey(
                at: written.place,
                placement: nil,
                position: written.position,
                anchor: written.anchor,
                scale: written.scale,
                rotation: written.rotation
            )
            if let (place, key) = key {
                throw ResolveError.cornerPinWithPlacement(place: place, kind: kind, key: key)
            }
            try checkConvexity(of: cornerPin, written: pin, place: written.place, kind: kind)
            pinned = ClipCornerPin(size: box, points: cornerPin)
        } else {
            pinned = nil
        }
        let bounds = Rectangle(x: 0, y: 0, width: box.width, height: box.height)
        let anchor = bounds.point(named: written.anchor ?? "center")
        let placed = position.map { $0.map(GeometryPoint.point) }
            ?? .value(.point(format.isMeasured ? anchor : format.frame.center))

        return StorylineAppearance(
            box: pinned == nil ? ClipBox(size: box, position: placed, anchor: anchor) : nil,
            cornerPin: pinned,
            opacity: property(written.opacity, plain: 1, clock: plan.map),
            scale: property(written.scale, plain: .identity, clock: plan.map),
            rotation: property(written.rotation, plain: 0, clock: plan.map),
            blend: written.blend ?? "normal",
            radius: try looks.timed(written.radius, key: "radius", as: LookStructureTable.radius),
            border: try border(written.border, looks: looks, theme: theme),
            shadow: try shadow(written.shadow, looks: looks, theme: theme)
        )
    }

    // A solid's colour, timed over its static value, which a keyframe's `null` points at.
    func solid(
        of written: StorylineClip,
        plan: StorylinePlan,
        theme: MergedTheme
    ) throws -> [Keyframe<Color>]? {
        guard let solid = written.solid else { return nil }

        let looks = ClipLookPlanner(
            place: written.place,
            kind: .clip(.solid),
            clock: plan.map,
            instant: plan.instant,
            scale: 1,
            theme: theme
        )
        guard case let .track(keyframes) = try looks.timed(solid, key: "solid", as: LookStructureTable.solid) else {
            return nil
        }

        return keyframes.compactMap { keyframe in
            guard case let .color(color) = keyframe.value else { return nil }

            return Keyframe(at: keyframe.at, value: color, ease: keyframe.ease)
        }
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
    // A corner pin given as numbers or found by text at a keyframe's time or as a static value is strictly convex,
    // checked in doubles as FRAMES-27 writes the test. One that holds a clip area takes that clip's box at each instant,
    // which only evaluation knows. A keyframe is named with its time as written.
    private func checkConvexity(
        of points: PropertyValue<GeometryQuad>,
        written: PropertyValue<[PositionForm]>,
        place: Place,
        kind: PlaceKind
    ) throws {
        let isConvex = { (points: GeometryQuad) in points.fixed?.isStrictlyConvex ?? true }
        switch (points, written) {
        case let (.value(points), _):
            guard isConvex(points) else {
                throw ResolveError.cornerPinNotConvex(place: place.appending(key: "cornerPin"), kind: kind, time: nil)
            }

        case let (.keyframes(keyframes), .keyframes(writtenKeyframes)):
            for keyframe in keyframes where !isConvex(keyframe.value) {
                let at = writtenKeyframes.first { $0.index == keyframe.index }?.at ?? keyframe.at
                throw ResolveError.cornerPinNotConvex(
                    place: place.appending(key: "keyframes").appending(index: keyframe.index).appending(key: "cornerPin"),
                    kind: kind,
                    time: at
                )
            }

        case (.keyframes, .value):
            return
        }
    }

    // A title's box is its text box, a media clip's is set by `width` and `height`, and a box shape's is its `width`
    // and `height` at the clip's instant. A shape placed by its geometry, an adjustment and a media clip without a
    // picture have none.
    private func boxSize(
        of plan: ClipPlan,
        written: Clip,
        crop: PropertyValue<FoundArea>?,
        title: TextLayout?,
        picture: Picture?,
        shape: ShapeAppearance?,
        format: FormatPlan
    ) -> Size? {
        switch written.content {
        case .title:
            return title?.size ?? Size(width: 0, height: 0)

        case .media:
            guard let picture else { return nil }

            return mediaSize(
                width: written.width,
                height: written.height,
                crop: crop,
                picture: picture.size,
                frame: format.isMeasured ? nil : format.size
            )

        case .shape:
            guard case let .box(width, height, _) = shape?.geometry else { return nil }

            return Size(width: value(of: width, at: plan.instant), height: value(of: height, at: plan.instant))

        case .adjust:
            return nil
        }
    }

    // The first key beside a corner pin that places a clip otherwise, with its place: on the clip at `place`, or in a
    // keyframe.
    private func placementKey(
        at place: Place,
        placement: String?,
        position: PropertyValue<PositionForm>?,
        anchor: String?,
        scale: PropertyValue<Scale>?,
        rotation: PropertyValue<Double>?
    ) -> (Place, String)? {
        if placement != nil {
            return (place.appending(key: "placement"), "placement")
        }
        if let position {
            return (self.place(of: position, key: "position", at: place), "position")
        }
        if anchor != nil {
            return (place.appending(key: "anchor"), "anchor")
        }
        if let scale {
            return (self.place(of: scale, key: "scale", at: place), "scale")
        }
        if let rotation {
            return (self.place(of: rotation, key: "rotation", at: place), "rotation")
        }
        return nil
    }

    // Where a property is written: the key of the clip at `place`, or the first keyframe that writes it.
    private func place<Value>(
        of property: PropertyValue<Value>,
        key: String,
        at place: Place
    ) -> Place {
        switch property {
        case .value:
            place.appending(key: key)

        case let .keyframes(keyframes):
            place.appending(key: "keyframes").appending(index: keyframes.map(\.index).min() ?? 0).appending(key: key)
        }
    }

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

    // A media clip's crops conform to its box by its `conform`, `fit` unless written, and without a crop its whole
    // picture does, so the box holds still while the crop moves. Its radius, border and shadow are timed by
    // `ClipLookPlanner`.
    private func mediaAppearance(
        of plan: ClipPlan,
        written: Clip,
        box: Size?,
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
            box: box,
            conform: conform,
            isTracked: written.track != nil,
            place: written.place.appending(key: "crop"),
            kind: .clip(plan.kind)
        )
        let bounds = Rectangle(x: 0, y: 0, width: box.width, height: box.height)
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
            radius: try looks.timed(written.radius, key: "radius", as: LookStructureTable.radius),
            border: try border(written.border, looks: looks, theme: theme),
            shadow: try shadow(written.shadow, looks: looks, theme: theme)
        )
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

    // A stroke inside or outside its outline needs a closed outline, which a rect and an ellipse always have, and no
    // head at either end, an end with none being off once its head is pinned. Its `align` and its ends' presets are
    // static names of the merged stroke, and `closed` is static.
    private func checkAlign(
        of stroke: TimedValue,
        shape: ClipShape,
        written: Clip,
        kind: PlaceKind
    ) throws {
        guard case let .fixed(.string(align))? = stroke["align"], align != StrokeAlign.center.rawValue else { return }

        let place = written.place.appending(key: "stroke")
        guard shape.kind != .path || shape.isClosed else {
            throw ResolveError.alignedStrokeOnOpenPath(place: place, kind: kind, align: align)
        }
        guard ["start", "end"].allSatisfy({ (stroke[$0] ?? .off) == .off }) else {
            throw ResolveError.alignedStrokeWithArrowhead(place: place, kind: kind, align: align)
        }
    }

    // A rect or an ellipse takes exactly one of `area` and the pair `width` and `height`, and only with the pair a
    // `placement`, and a path its points, its static value and every keyframe of them as many vertices, each vertex's
    // point written statically or in a keyframe.
    private func checkGeometry(
        of shape: ClipShape,
        written: Clip,
        kind: PlaceKind
    ) throws {
        guard shape.kind != .path else {
            guard let points = shape.points else {
                throw ResolveError.missingKey(place: written.place, kind: kind, key: "points")
            }

            let count = points.written?.count ?? points.keyframes[0].value.count
            if let other = points.keyframes.first(where: { $0.value.count != count }) {
                throw ResolveError.pointCountsDiffer(
                    place: written.place.appending(key: "keyframes").appending(index: other.index).appending(key: "points"),
                    kind: kind,
                    counts: [count, other.value.count]
                )
            }
            if let index = points.vertices.firstIndex(where: { $0.vertex == .keyframes([]) }) {
                throw ResolveError.missingKey(
                    place: written.place.appending(key: "keyframes").appending(index: points.keyframes[0].index)
                        .appending(key: "points").appending(index: index),
                    kind: kind,
                    key: "vertex"
                )
            }
            return
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

        case .file, .imageSequence, .page, .compound:
            false
        }
    }

    private func media(of clip: Clip) -> ClipMedia? {
        guard case let .media(media) = clip.content else { return nil }

        return media
    }
}
