//
//  ResolveError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ResolveError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyStoryline(place: Place, kind: PlaceKind)
    case unprobedMedia(place: Place, kind: PlaceKind, reference: String)
    case unknownTheme(place: Place, kind: PlaceKind, name: String)
    case missingKey(place: Place, kind: PlaceKind, key: String)
    case nonPositiveDuration(place: Place, kind: PlaceKind, duration: Double)
    case emptyClipRange(place: Place, kind: PlaceKind, in: Double, out: Double)
    case inAtOrAfterMediaEnd(place: Place, kind: PlaceKind, in: Double, end: Double)
    case outAtOrBeforeMediaStart(place: Place, kind: PlaceKind, out: Double)
    case nonPositiveSpeed(place: Place, kind: PlaceKind, speed: Double)
    case transitionOnFirstClip(place: Place, kind: PlaceKind)
    case unknownPreset(place: Place, kind: PlaceKind, presetKind: String, name: String)
    case emptyWindow(place: Place, kind: PlaceKind, start: Double, end: Double)
    case neverVisible(place: Place, kind: PlaceKind, window: TimeRange, range: TimeRange)
    case neverPlays(place: Place, kind: PlaceKind, window: TimeRange)
    case audioStartOutsideDrawnRange(place: Place, kind: PlaceKind, start: Double, drawn: TimeRange)
    case startsAtOrAfterEnd(place: Place, kind: PlaceKind, start: Double, end: Double)
    case zeroLane(place: Place, kind: PlaceKind)
    case parentWithPlacement(place: Place, kind: PlaceKind)
    case parentOnSequenceClip(place: Place, kind: PlaceKind)
    case keyframesOutsideVisibleRange(place: Place, kind: PlaceKind, property: String, visible: TimeRange)
    case missingFormatSize(place: Place, kind: PlaceKind)
    case noContentRect(place: Place, kind: PlaceKind, size: Size)
    case soundAsPicture(place: Place, kind: PlaceKind, reference: String)
    case outsideCanvas(place: Place, kind: PlaceKind, size: Size)
    case emptyLayout(place: Place, kind: PlaceKind)
    case nonPositiveColumns(place: Place, kind: PlaceKind, columns: Int)
    case areaPositionWithoutParent(place: Place, kind: PlaceKind)
    case trackWithoutVideo(place: Place, kind: PlaceKind)
    case trackOwnWithoutArea(place: Place, kind: PlaceKind)
    case trackOwnOnNamingClip(place: Place, kind: PlaceKind)
    case trackLost(place: Place, kind: PlaceKind, followed: TimeRange, edit: TimeRange)
    case neverFollowed(place: Place, kind: PlaceKind, visible: TimeRange)
    case labelWithoutRoom(place: Place, kind: PlaceKind, label: String, sides: [Side], room: String)
    case unreadableFile(path: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .emptyStoryline(place, kind):
            "\(place) (\(kind.label)): the storyline is empty, and a sequence needs at least one storyline clip"

        case let .unprobedMedia(place, kind, reference):
            "\(place) (\(kind.label)): media \(quoted(reference)) has no probed facts"

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

        case let .transitionOnFirstClip(place, kind):
            "\(place) (\(kind.label)): the first storyline clip has no transition. "
                + "To open from black, put a solid clip first and give the clip after it the transition"

        case let .unknownPreset(place, kind, presetKind, name):
            "\(place) (\(kind.label)): unknown \(presetKind) preset \(quoted(name))"

        case let .emptyWindow(place, kind, start, end):
            "\(place) (\(kind.label)): the window [\(number(start)), \(number(end))] ends before it starts"

        case let .neverVisible(place, kind, window, range):
            "\(place) (\(kind.label)): "
                + "never visible, since its window \(written(window)) does not meet \(written(range))"

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
            "\(place) (\(kind.label)): "
                + "\"parent\": true cannot take \"placement\", since placement names the output frame"

        case let .parentOnSequenceClip(place, kind):
            "\(place) (\(kind.label)): a sequence clip has no parent, so it cannot take \"parent\": true"

        case let .keyframesOutsideVisibleRange(place, kind, property, visible):
            "\(place) (\(kind.label)): every keyframe of \(quoted(property)) lies outside \(written(visible)), "
                + "so only one of its values would ever show"

        case let .missingFormatSize(place, kind):
            "\(place) (\(kind.label)): the storyline has no video and its first clip is a solid, which has no size, "
                + "so the format needs \"size\""

        case let .noContentRect(place, kind, size):
            "\(place) (\(kind.label)): the inset leaves no content rect in the output of "
                + "\(number(size.width))x\(number(size.height))"

        case let .soundAsPicture(place, kind, reference):
            "\(place) (\(kind.label)): media \(quoted(reference)) is sound, and a picture is taken here"

        case let .outsideCanvas(place, kind, size):
            "\(place) (\(kind.label)): lies wholly outside the canvas of "
                + "\(number(size.width))x\(number(size.height)) at its operation"

        case let .emptyLayout(place, kind):
            "\(place) (\(kind.label)): a layout needs at least one item"

        case let .nonPositiveColumns(place, kind, columns):
            "\(place) (\(kind.label)): columns must be 1 or more, found \(columns)"

        case let .areaPositionWithoutParent(place, kind):
            "\(place) (\(kind.label)): a position given by an area is in the picture of a parented clip, "
                + "so it needs \"parent\": true"

        case let .trackWithoutVideo(place, kind):
            "\(place) (\(kind.label)): track follows the video or image sequence of a storyline clip, "
                + "and there is none to follow here"

        case let .trackOwnWithoutArea(place, kind):
            "\(place) (\(kind.label)): \"track\": true follows the clip's own area or crop, "
                + "and it has none given as an area"

        case let .trackOwnOnNamingClip(place, kind):
            "\(place) (\(kind.label)): a title or media clip names the area it tracks, "
                + "so it cannot take \"track\": true"

        case let .trackLost(place, kind, followed, edit):
            "\(place) (\(kind.label)): the tracker follows its target only over \(written(followed)) and loses it "
                + "inside the edit range \(written(edit))"

        case let .neverFollowed(place, kind, visible):
            "\(place) (\(kind.label)): never visible, since the tracker follows its target on none of the frames "
                + "of its visible range \(written(visible))"

        case let .labelWithoutRoom(place, kind, label, sides, room):
            "\(place) (\(kind.label)): the label \(quoted(label)) fits inside the \(room) on none of the sides "
                + sides.map(\.rawValue).joined(separator: ", ")

        case let .unreadableFile(path):
            "\(quoted(path)): the file cannot be read, so it cannot be pinned by its SHA-256"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }

    private func written(_ range: TimeRange) -> String {
        "[\(number(range.start)), \(number(range.end)))"
    }
}
