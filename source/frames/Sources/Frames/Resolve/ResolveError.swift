//
//  ResolveError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ResolveError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyStoryline(place: Place, kind: PlaceKind)
    case missingMedia(place: Place, kind: PlaceKind, reference: String)
    case unreadableMedia(place: Place, kind: PlaceKind, reference: String, reason: String)
    case unconvertibleMediaColor(place: Place, kind: PlaceKind, reference: String)
    case unknownTheme(place: Place, kind: PlaceKind, name: String)
    case missingKey(place: Place, kind: PlaceKind, key: String)
    case nonPositiveDuration(place: Place, kind: PlaceKind, duration: Double)
    case emptyClipRange(place: Place, kind: PlaceKind, in: Double, out: Double)
    case inAtOrAfterMediaEnd(place: Place, kind: PlaceKind, in: Double, end: Double)
    case outAtOrBeforeMediaStart(place: Place, kind: PlaceKind, out: Double)
    case nonPositiveSpeed(place: Place, kind: PlaceKind, speed: Double)
    case speedWithTimeRemap(place: Place, kind: PlaceKind)
    case soundWithTimeRemap(place: Place, kind: PlaceKind, key: String)
    case audioWithoutSound(place: Place, kind: PlaceKind)
    case audioFilterWithoutSound(place: Place, kind: PlaceKind)
    case splitWithoutSound(place: Place, kind: PlaceKind)
    // `place` names the edge, `split.before` or `split.after`.
    case splitPastMedia(place: Place, kind: PlaceKind)
    case splitOutsideSequence(place: Place, kind: PlaceKind)
    case rangeWithTimeRemap(place: Place, kind: PlaceKind, key: String)
    case singleStartWithTimeRemap(place: Place, kind: PlaceKind)
    case transitionOnFirstClip(place: Place, kind: PlaceKind)
    case unknownPreset(place: Place, kind: PlaceKind, preset: UnknownPreset)
    case unknownPresetFile(place: Place, kind: PlaceKind, name: String)
    case unknownPresetColor(place: Place, kind: PlaceKind, name: String)
    case unusableDisplacementMap(place: Place, kind: PlaceKind, reference: String, refusal: DisplacementMapRefusal)
    case unusableImpulseResponse(place: Place, kind: PlaceKind, reference: String, refusal: ImpulseResponseRefusal)
    case emptyWindow(place: Place, kind: PlaceKind, start: Double, end: Double)
    case neverVisible(place: Place, kind: PlaceKind, window: TimeRange, range: TimeRange)
    case cropOutsideMedia(place: Place, kind: PlaceKind, crop: Rectangle, size: Size)
    case neverPlays(place: Place, kind: PlaceKind, window: TimeRange)
    case audioStartOutsideDrawnRange(place: Place, kind: PlaceKind, start: Double, drawn: TimeRange)
    case startsAtOrAfterEnd(place: Place, kind: PlaceKind, start: Double, end: Double)
    case zeroLane(place: Place, kind: PlaceKind)
    case parentWithPlacement(place: Place, kind: PlaceKind)
    case placementWithPosition(place: Place, kind: PlaceKind)
    case parentWithoutPosition(place: Place, kind: PlaceKind)
    case titleWithoutPlacement(place: Place, kind: PlaceKind, style: String)
    case keyframesOutsideVisibleRange(place: Place, kind: PlaceKind, leaf: String, visible: TimeRange)
    case missingFormatSize(place: Place, kind: PlaceKind)
    case contentFitWithoutPicture(place: Place, kind: PlaceKind)
    case soundAsPicture(place: Place, kind: PlaceKind, reference: String)
    case shapeAreaWithBox(place: Place, kind: PlaceKind)
    case placementWithoutBox(place: Place, kind: PlaceKind)
    case shapeWithoutGeometry(place: Place, kind: PlaceKind)
    case pointCountsDiffer(place: Place, kind: PlaceKind, counts: [Int])
    case shapeDrawsNothing(place: Place, kind: PlaceKind)
    case alignedStrokeOnOpenPath(place: Place, kind: PlaceKind, align: String)
    case alignedStrokeWithArrowhead(place: Place, kind: PlaceKind, align: String)
    case cornerPinWithPlacement(place: Place, kind: PlaceKind, key: String)
    case cornerPinOnGeometry(place: Place, kind: PlaceKind)
    case cornerPinNotConvex(place: Place, kind: PlaceKind, time: Double?)
    // `time` is the keyframe's, nil for a static corner pin found at the clip's instant.
    case cornerPinNotBroughtBack(place: Place, kind: PlaceKind, time: Double)
    case trackOnStorylineCornerPin(place: Place, kind: PlaceKind)
    // `layer` is the theme layer that turned the value off, nil where no layer of the look gives one.
    case missingLookLeaf(place: Place, kind: PlaceKind, key: String, layer: Place?)
    case partialChoiceOverNone(place: Place, kind: PlaceKind, layer: Place?)
    case partialChoiceOverList(place: Place, kind: PlaceKind, layer: Place)
    case unitsOnNonTitle(place: Place, kind: PlaceKind)
    case staggerWithoutBy(place: Place, kind: PlaceKind)
    case orderWithoutBy(place: Place, kind: PlaceKind)
    case unitsWithoutSpan(place: Place, kind: PlaceKind)
    case unknownParent(place: Place, kind: PlaceKind, id: String)
    case audioParent(place: Place, kind: PlaceKind, id: String)
    case parentCycle(place: Place, kind: PlaceKind, ids: [String])
    case unknownTrackMatte(place: Place, kind: PlaceKind, id: String)
    case trackMatteKind(place: Place, kind: PlaceKind, id: String, matte: TrackMatteRefusal)
    case trackMatteCycle(place: Place, kind: PlaceKind, ids: [String])
    case unknownClipArea(place: Place, kind: PlaceKind, id: String)
    case clipAreaKind(place: Place, kind: PlaceKind, id: String, named: TrackMatteRefusal)
    case clipAreaAcrossSpaces(place: Place, kind: PlaceKind, id: String, parent: String?, namedParent: String?)
    case clipAreaCycle(place: Place, kind: PlaceKind, ids: [String])
    case clipAreaOnStoryline(place: Place, kind: PlaceKind)
    case trackWithoutVideo(place: Place, kind: PlaceKind)
    case trackLost(place: Place, kind: PlaceKind, followed: TimeRange, edit: TimeRange)
    case neverFollowed(place: Place, kind: PlaceKind, visible: TimeRange)
    case trackTimeOutside(place: Place, kind: PlaceKind, time: Double)
    case instantNotFollowed(place: Place, kind: PlaceKind, mediaTime: Double)
    case trackData(place: Place, kind: PlaceKind, reason: TrackDataRefusal)
    case unreadableFile(path: String)
    case unreadableResolvedVersion(place: Place, kind: String, written: String, current: String)
    case optionOnResolved(place: Place, kind: String, option: String)
    case mediaColorSpaces(
        place: String,
        kind: String,
        other: String,
        file: String,
        colorSpace: ColorSpace?,
        otherColorSpace: ColorSpace?
    )

    // MARK: - Property
    var description: String {
        switch self {
        case let .emptyStoryline(place, kind):
            "\(place) (\(kind.label)): the storyline is empty, and a sequence needs at least one storyline clip"

        case let .missingMedia(place, kind, reference):
            "\(place) (\(kind.label)): media \(quoted(reference)) is not there"

        case let .unreadableMedia(place, kind, reference, reason):
            "\(place) (\(kind.label)): media \(quoted(reference)) cannot be probed: \(reason)"

        case let .unconvertibleMediaColor(place, kind, reference):
            "\(place) (\(kind.label)): media \(quoted(reference)) is tagged with a LUT-based ICC profile or a code "
                + "point H.273 reserves, which no fixed formula converts. Write the colorSpace it is in here, or "
                + "convert it with transcode"

        case let .unknownTheme(place, kind, name):
            "\(place) (\(kind.label)): unknown theme \(quoted(name)). "
                + "A theme is named <pack>/<name> or by an absolute path"

        case let .missingKey(place, kind, key):
            "\(place) (\(kind.label)): missing key \(quoted(key))"

        case let .nonPositiveDuration(place, kind, duration):
            "\(place) (\(kind.label)): a still or solid clip needs a duration above 0, found \(number(duration))"

        case let .emptyClipRange(place, kind, start, end):
            "\(place) (\(kind.label)): in \(number(start)) is not before out \(number(end)) of the media"

        case let .inAtOrAfterMediaEnd(place, kind, start, end):
            "\(place) (\(kind.label)): in \(number(start)) is at or after the end of the media at \(number(end))"

        case let .outAtOrBeforeMediaStart(place, kind, end):
            "\(place) (\(kind.label)): out \(number(end)) is at or before the start of the media"

        case let .nonPositiveSpeed(place, kind, speed):
            "\(place) (\(kind.label)): speed must be above 0, found \(number(speed))"

        case let .speedWithTimeRemap(place, kind):
            "\(place) (\(kind.label)): a clip with \"timeRemap\" takes no \"speed\", since its keys give the media time "
                + "at every instant"

        case let .soundWithTimeRemap(place, kind, key):
            "\(place) (\(kind.label)): a clip with \"timeRemap\" plays no sound, so \"\(key)\" would do nothing. "
                + "Place the shot's sound as an audio clip of its own"

        case let .audioWithoutSound(place, kind):
            "\(place) (\(kind.label)): an audio clip takes its media's sound, and this media holds none, so the clip "
                + "would play nothing"

        case let .audioFilterWithoutSound(place, kind):
            "\(place) (\(kind.label)): this clip plays no sound, so \"audioFilter\" would do nothing"

        case let .splitWithoutSound(place, kind):
            "\(place) (\(kind.label)): this clip plays no sound, so a split has no sound to move"

        case let .splitPastMedia(place, kind):
            "\(place) (\(kind.label)): the split moves the clip's sound past where its media holds sound"

        case let .splitOutsideSequence(place, kind):
            "\(place) (\(kind.label)): the split moves the clip's sound outside the sequence"

        case let .rangeWithTimeRemap(place, kind, key):
            "\(place) (\(kind.label)): a media clip with \"timeRemap\" takes no \"\(key)\", since its keys give the "
                + "media time at every instant of its window"

        case let .singleStartWithTimeRemap(place, kind):
            "\(place) (\(kind.label)): a media clip with \"timeRemap\" takes \"at\" as [start, end], since its keys and "
                + "not its media give its length"

        case let .transitionOnFirstClip(place, kind):
            "\(place) (\(kind.label)): the first storyline clip has no transition. "
                + "To open from black, put a solid clip first and give the clip after it the transition"

        case let .unknownPreset(place, kind, preset):
            "\(place) (\(kind.label)): \(preset)"

        case let .unknownPresetFile(place, kind, name):
            "\(place) (\(kind.label)): the preset names the file \(quoted(name)), which names nothing. "
                + "A preset names a file by <pack>/<name> or by an absolute path"

        case let .unknownPresetColor(place, kind, name):
            "\(place) (\(kind.label)): the preset names the colour \(quoted(name)), which is not in the theme's colors"

        case let .unusableDisplacementMap(place, kind, reference, refusal):
            "\(place) (\(kind.label)): the displacement map \(quoted(reference)) \(words(of: refusal))"

        case let .unusableImpulseResponse(place, kind, reference, refusal):
            "\(place) (\(kind.label)): the impulse response \(quoted(reference)) \(words(of: refusal))"

        case let .emptyWindow(place, kind, start, end):
            "\(place) (\(kind.label)): the window [\(number(start)), \(number(end))] ends before it starts"

        case let .neverVisible(place, kind, window, range):
            "\(place) (\(kind.label)): "
                + "never visible, since its window \(written(window)) does not meet \(written(range))"

        case let .cropOutsideMedia(place, kind, crop, size):
            "\(place) (\(kind.label)): never visible, since its crop conformed to its box is \(written(crop)), which "
                + "lies wholly outside its media of \(number(size.width))x\(number(size.height))"

        case let .neverPlays(place, kind, window):
            "\(place) (\(kind.label)): never plays, since its window \(written(window)) ends before the sequence starts"

        case let .audioStartOutsideDrawnRange(place, kind, start, drawn):
            "\(place) (\(kind.label)): "
                + "starts at \(number(start)), outside its storyline clip's drawn range \(written(drawn))"

        case let .startsAtOrAfterEnd(place, kind, start, end):
            "\(place) (\(kind.label)): "
                + "starts at \(number(start)), at or after the end of the sequence at \(number(end))"

        case let .zeroLane(place, kind):
            "\(place) (\(kind.label)): lane 0 is the storyline. A clip takes a lane above or below it"

        case let .parentWithPlacement(place, kind):
            "\(place) (\(kind.label)): a parented clip cannot take \"placement\", "
                + "since placement names the frame and not its parent's space"

        case let .placementWithPosition(place, kind):
            "\(place) (\(kind.label)): \"placement\" and \"position\" both place the clip, so it takes one of them"

        case let .parentWithoutPosition(place, kind):
            "\(place) (\(kind.label)): a parented clip has no default place, so it needs \"position\""

        case let .titleWithoutPlacement(place, kind, style):
            "\(place) (\(kind.label)): style \(quoted(style)) gives no placement, so the title needs \"placement\" or "
                + "\"position\""

        case let .keyframesOutsideVisibleRange(place, kind, leaf, visible):
            "\(place) (\(kind.label)): every keyframe of \(quoted(leaf)) lies outside \(written(visible)), "
                + "so only one of its values would ever show"

        case let .missingFormatSize(place, kind):
            "\(place) (\(kind.label)): the storyline has no video and its first clip is a solid, which has no size, "
                + "so the format needs \"size\""

        case let .contentFitWithoutPicture(place, kind):
            "\(place) (\(kind.label)): every storyline clip is a solid, so a frame measured from the content has "
                + "nothing to measure and no length scale, and the format needs \"size\""

        case let .soundAsPicture(place, kind, reference):
            "\(place) (\(kind.label)): media \(quoted(reference)) is sound, and a picture is taken here"

        case let .shapeAreaWithBox(place, kind):
            "\(place) (\(kind.label)): \(boxed(kind)) is given by \"area\" or by \"width\" and \"height\", "
                + "and this one writes both"

        case let .placementWithoutBox(place, kind):
            "\(place) (\(kind.label)): \"placement\" places a box given by \"width\" and \"height\", "
                + "and \(kind == .clip(.null) ? "a null" : "a shape") given by \"area\" is placed by its area"

        case let .shapeWithoutGeometry(place, kind):
            "\(place) (\(kind.label)): \(boxed(kind)) needs \"area\", or \"width\" and \"height\""

        case let .cornerPinWithPlacement(place, kind, key):
            "\(place) (\(kind.label)): a clip placed by \"cornerPin\" takes no \(quoted(key)), since its corner pin places it"

        case let .cornerPinOnGeometry(place, kind):
            "\(place) (\(kind.label)): a shape placed by its area takes no \"cornerPin\", "
                + "since its outline is in its space already"

        case let .cornerPinNotBroughtBack(place, kind, time):
            "\(place) (\(kind.label)): the corner pin at \(number(time))"
                + ", brought back through the inverse of the track's homography there, does not lie wholly in front of its "
                + "horizon or is not strictly convex"

        case let .cornerPinNotConvex(place, kind, time):
            "\(place) (\(kind.label)): the corner pin\(time.map { " at \(number($0))" } ?? "") is not strictly convex, "
                + "so no homography takes the clip's box to it"

        case let .trackOnStorylineCornerPin(place, kind):
            "\(place) (\(kind.label)): a storyline clip with a corner pin is placed in the frame, which has no media "
                + "to follow, so it takes no \"track\""

        case let .pointCountsDiffer(place, kind, counts):
            "\(place) (\(kind.label)): the values of \"points\" hold "
                + counts.map { "\($0)" }.joined(separator: " and ")
                + " vertices, and a path interpolates vertex by vertex, so every value has the same number"

        case let .missingLookLeaf(place, kind, key, .some(layer)):
            "\(place) (\(kind.label)): missing key \"\(key)\", which the clip does not write and its theme turns off (\(layer))"

        case let .missingLookLeaf(place, kind, key, .none):
            "\(place) (\(kind.label)): missing key \"\(key)\", which the clip does not write and no theme layer gives"

        case let .partialChoiceOverNone(place, kind, .some(layer)):
            "\(place) (\(kind.label)): a choice without a preset changes the theme's default, which is none here (\(layer))"

        case let .partialChoiceOverNone(place, kind, .none):
            "\(place) (\(kind.label)): a choice without a preset changes the theme's default, and this clip takes none"

        case let .partialChoiceOverList(place, kind, layer):
            "\(place) (\(kind.label)): a choice without a preset over the theme's default list (\(layer)), where which entry it changes is ambiguous"

        case let .unitsOnNonTitle(place, kind):
            "\(place) (\(kind.label)): `by` plays a title's animation by unit, and this clip is not a title"

        case let .staggerWithoutBy(place, kind):
            "\(place) (\(kind.label)): `stagger` spaces a title's units, and the choice names no unit with `by`"

        case let .orderWithoutBy(place, kind):
            "\(place) (\(kind.label)): `order` orders a title's units, and the choice names no unit with `by`"

        case let .unitsWithoutSpan(place, kind):
            "\(place) (\(kind.label)): `by` plays the entrance and the exit by unit, and the choice has neither"

        case let .shapeDrawsNothing(place, kind):
            "\(place) (\(kind.label)): the shape has neither a fill nor a stroke after its style, so it draws nothing"

        case let .alignedStrokeOnOpenPath(place, kind, align):
            "\(place) (\(kind.label)): a stroke \"\(align)\" its outline needs a closed outline, and the path is open"

        case let .alignedStrokeWithArrowhead(place, kind, align):
            "\(place) (\(kind.label)): a stroke \"\(align)\" its outline takes no arrowhead, which lies across the "
                + "outline with its tip at the end while the stroke lies on one side of it"

        case let .unknownParent(place, kind, id):
            "\(place) (\(kind.label)): no clip in the document has the id \(quoted(id))"

        case let .audioParent(place, kind, id):
            "\(place) (\(kind.label)): \(quoted(id)) is an audio clip, which has no picture to be a parent"

        case let .parentCycle(place, kind, ids):
            "\(place) (\(kind.label)): the parent chain comes back to itself: "
                + (ids + ids.prefix(1)).map(quoted).joined(separator: " > ")

        case let .unknownTrackMatte(place, kind, id):
            "\(place) (\(kind.label)): no clip in the document has the id \(quoted(id)), "
                + "and a track matte is a clip of the same document"

        case let .trackMatteKind(place, kind, id, matte):
            "\(place) (\(kind.label)): \(quoted(id)) is \(words(of: matte)), "
                + "and a track matte is a connected or sequence media clip, title or shape"

        case let .trackMatteCycle(place, kind, ids):
            "\(place) (\(kind.label)): the track matte chain comes back to itself: "
                + (ids + ids.prefix(1)).map(quoted).joined(separator: " > ")

        case let .unknownClipArea(place, kind, id):
            "\(place) (\(kind.label)): no clip of this document has the id \(quoted(id))"

        case let .clipAreaKind(place, kind, id, named):
            "\(place) (\(kind.label)): \(quoted(id)) is \(words(of: named)), "
                + "and a clip area names a connected or sequence media clip, title, shape or null"

        case let .clipAreaAcrossSpaces(place, kind, id, parent, namedParent):
            "\(place) (\(kind.label)): this clip's parent is \(parent.map(quoted) ?? "none") and the parent of "
                + "\(quoted(id)) is \(namedParent.map(quoted) ?? "none"), so its box is in another coordinate space. "
                + "A clip area names a clip with the same parent, or with none where this clip has none, or this "
                + "clip's own parent"

        case let .clipAreaCycle(place, kind, ids):
            "\(place) (\(kind.label)): the clip areas come back to the box they start from: "
                + (ids + ids.prefix(1)).map(quoted).joined(separator: " > ")

        case let .clipAreaOnStoryline(place, kind):
            "\(place) (\(kind.label)): a storyline clip is placed by the storyline in output pixels, so it takes "
                + "no clip area"

        case let .trackWithoutVideo(place, kind):
            "\(place) (\(kind.label)): track follows the video or image sequence of the clip or of its parent, "
                + "and there is none to follow here"

        case let .trackLost(place, kind, followed, edit):
            "\(place) (\(kind.label)): the track data follows its target only over \(written(followed)) and loses it "
                + "inside the edit range \(written(edit))"

        case let .neverFollowed(place, kind, visible):
            "\(place) (\(kind.label)): never visible, since the track data follows its target on none of the frames "
                + "of its visible range \(written(visible))"

        case let .trackTimeOutside(place, kind, time):
            "\(place) (\(kind.label)): media time \(number(time)) names no frame of the tracked media"

        case let .instantNotFollowed(place, kind, mediaTime):
            "\(place) (\(kind.label)): the clip's instant shows media time \(number(mediaTime)), a frame the track data "
                + "does not name, so its window holds none"

        case let .trackData(place, kind, reason):
            "\(place) (\(kind.label)): \(words(of: reason))"

        case let .unreadableFile(path):
            "\(quoted(path)): the file cannot be read, so it cannot be pinned by its SHA-256"

        case let .unreadableResolvedVersion(place, kind, written, current):
            "\(place) (\(kind)): the resolved document was written by frames \(quoted(written)), and frames "
                + "\(current) reads only one written by frames \(current.split(separator: ".").prefix(1).joined()).0 "
                + "up to \(current.split(separator: ".").prefix(2).joined(separator: "."))"

        case let .optionOnResolved(place, kind, option):
            "\(place) (\(kind)): a resolved document has its theme and arguments written in, so it takes no \(option)"

        case let .mediaColorSpaces(place, kind, other, file, colorSpace, otherColorSpace):
            "\(place) (\(kind)): \(quoted(file)) is read \(read(in: colorSpace)) here and \(read(in: otherColorSpace)) "
                + "at \(other), and every place that names a file reads it in one colour space"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func words(of refusal: TrackDataRefusal) -> String {
        switch refusal {
        case .outsideMedia:
            "the frame's time names no frame of the tracked media"

        case .notConvex:
            "the quad is not strictly convex"

        case .otherOrientation:
            "the quad runs the other way round than the quad of the frame \"time\" names"

        case .outOfOrder:
            "the frames are not in time order"

        case .sameFrame:
            "two frames name one media frame"

        case .gap:
            "a media frame between this frame and the one before it has no frame of the data"

        case .noTarget:
            "\"time\" names no frame of \"frames\", so the data gives no target"
        }
    }

    private func words(of refusal: DisplacementMapRefusal) -> String {
        switch refusal {
        case .video:
            "is a video, and a displacement map is a raster still"

        case .imageSequence:
            "is an image sequence, and a displacement map is a raster still"

        case .page:
            "is a PDF, and a displacement map is a raster still"

        case .sequence:
            "is a sequence document, and a displacement map is a raster still"

        case .sound:
            "is sound, and a displacement map is a raster still"

        case .unconvertibleColor:
            "is tagged with a LUT-based ICC profile or a code point H.273 reserves, which no fixed formula converts, "
                + "and a displacement map is read as its tags say. Convert it with transcode"
        }
    }

    private func words(of refusal: ImpulseResponseRefusal) -> String {
        switch refusal {
        case .noSound:
            "has no sound, and an impulse response is sound"

        case .imageSequence:
            "is an image sequence, and an impulse response is sound"

        case .page:
            "is a PDF, and an impulse response is sound"

        case .sequence:
            "is a sequence document, and an impulse response is sound"

        case .noSamples:
            "holds no samples, and an impulse response holds at least one"

        case let .tooLong(duration):
            "is \(number(duration)) seconds long, and an impulse response is at most \(number(MixConvolution.longestDuration)) seconds"
        }
    }

    private func words(of refusal: TrackMatteRefusal) -> String {
        switch refusal {
        case .storyline:
            "a storyline clip"

        case .adjustment:
            "an adjustment clip"

        case .audio:
            "an audio clip"

        case .null:
            "a null, which draws nothing"
        }
    }

    // The clips whose box is given by `area` or by `width` and `height`, as a message about one of them names them.
    private func boxed(_ kind: PlaceKind) -> String {
        kind == .clip(.null) ? "a null" : "a rect or ellipse"
    }

    private func read(in colorSpace: ColorSpace?) -> String {
        colorSpace.map { "as \(quoted($0.rawValue))" } ?? "as its tags say"
    }

    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }

    // A range of time is written as machine output writes times, rounded to the microsecond.
    private func written(_ range: TimeRange) -> String {
        "[\(JSONValue.time(range.start).written), \(JSONValue.time(range.end).written))"
    }

    private func written(_ rectangle: Rectangle) -> String {
        "[\([rectangle.x, rectangle.y, rectangle.width, rectangle.height].map(number).joined(separator: ", "))]"
    }
}
