//
//  ResolveError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ResolveError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyStoryline(place: Place)
    case unprobedMedia(place: Place, kind: String, reference: String)
    case unreadReference(place: Place, kind: String, reference: String)
    case missingKey(place: Place, kind: String, key: String)
    case nonPositiveDuration(place: Place, kind: String, duration: Double)
    case emptyClipRange(place: Place, kind: String, in: Double, out: Double)
    case nonPositiveSpeed(place: Place, kind: String, speed: Double)
    case transitionOnFirstClip(place: Place, kind: String)
    case unknownPreset(place: Place, kind: String, presetKind: String, name: String)
    case nonPositiveTransition(place: Place, kind: String, seconds: Double)
    case emptyWindow(place: Place, kind: String, start: Double, end: Double)
    case neverVisible(place: Place, kind: String, window: TimeRange, range: TimeRange)
    case neverPlays(place: Place, kind: String, window: TimeRange)
    case audioStartOutsideDrawnRange(place: Place, kind: String, start: Double, drawn: TimeRange)
    case startsAtOrAfterEnd(place: Place, kind: String, start: Double, end: Double)
    case zeroLane(place: Place, kind: String)
    case parentWithPlacement(place: Place, kind: String)
    case parentOnSequenceClip(place: Place, kind: String)
    case keyframesOutsideVisibleRange(place: Place, kind: String, property: String, visible: TimeRange)

    // MARK: - Property
    var description: String {
        switch self {
        case let .emptyStoryline(place):
            "\(place) (sequence): the storyline is empty, and a sequence needs at least one storyline clip"

        case let .unprobedMedia(place, kind, reference):
            "\(place) (\(kind)): media \(quoted(reference)) has no probed facts"

        case let .unreadReference(place, kind, reference):
            "\(place) (\(kind)): \(quoted(reference)) is not read before time is planned"

        case let .missingKey(place, kind, key):
            "\(place) (\(kind)): missing key \(quoted(key))"

        case let .nonPositiveDuration(place, kind, duration):
            "\(place) (\(kind)): a still or solid clip needs a duration above 0, found \(number(duration))"

        case let .emptyClipRange(place, kind, start, end):
            "\(place) (\(kind)): in \(number(start)) is not before out \(number(end)) of the media"

        case let .nonPositiveSpeed(place, kind, speed):
            "\(place) (\(kind)): speed must be above 0, found \(number(speed))"

        case let .transitionOnFirstClip(place, kind):
            "\(place) (\(kind)): the first storyline clip has no transition. To open from black, put a solid clip first "
                + "and give the clip after it the transition"

        case let .unknownPreset(place, kind, presetKind, name):
            "\(place) (\(kind)): unknown \(presetKind) preset \(quoted(name))"

        case let .nonPositiveTransition(place, kind, seconds):
            "\(place) (\(kind)): a transition lasts more than 0 seconds, found \(number(seconds))"

        case let .emptyWindow(place, kind, start, end):
            "\(place) (\(kind)): the window [\(number(start)), \(number(end))] ends before it starts"

        case let .neverVisible(place, kind, window, range):
            "\(place) (\(kind)): never visible, since its window \(written(window)) does not meet \(written(range))"

        case let .neverPlays(place, kind, window):
            "\(place) (\(kind)): never plays, since its window \(written(window)) ends before the sequence starts"

        case let .audioStartOutsideDrawnRange(place, kind, start, drawn):
            "\(place) (\(kind)): starts at \(number(start)), outside its storyline clip's drawn range \(written(drawn))"

        case let .startsAtOrAfterEnd(place, kind, start, end):
            "\(place) (\(kind)): starts at \(number(start)), at or after the end of the sequence at \(number(end))"

        case let .zeroLane(place, kind):
            "\(place) (\(kind)): lane 0 is the storyline. A clip takes a lane above or below it"

        case let .parentWithPlacement(place, kind):
            "\(place) (\(kind)): \"parent\": true cannot take \"placement\", since placement names the output frame"

        case let .parentOnSequenceClip(place, kind):
            "\(place) (\(kind)): a sequence clip has no parent, so it cannot take \"parent\": true"

        case let .keyframesOutsideVisibleRange(place, kind, property, visible):
            "\(place) (\(kind)): every keyframe of \(quoted(property)) lies outside \(written(visible)), "
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
