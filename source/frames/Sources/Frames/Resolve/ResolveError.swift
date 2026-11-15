//
//  ResolveError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ResolveError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyStoryline(place: Place, kind: PlaceKind)
    case unprobedMedia(place: Place, kind: PlaceKind, reference: String)
    case unreadReference(place: Place, kind: PlaceKind, reference: String)
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

    // MARK: - Property
    var description: String {
        switch self {
        case let .emptyStoryline(place, kind):
            "\(place) (\(kind.label)): the storyline is empty, and a sequence needs at least one storyline clip"

        case let .unprobedMedia(place, kind, reference):
            "\(place) (\(kind.label)): media \(quoted(reference)) has no probed facts"

        case let .unreadReference(place, kind, reference):
            "\(place) (\(kind.label)): \(quoted(reference)) is not read before time is planned"

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
