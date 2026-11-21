//
//  AnalysisError.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

enum AnalysisError: Error, Equatable, CustomStringConvertible, Sendable {
    case missingMedia(file: String)
    case noPicture(file: String)
    case notVideo(file: String, kind: MediaKind)
    case timeOnImage(file: String)
    case beforeMediaStart(option: String, time: Double, file: String)
    case atOrAfterMediaEnd(option: String, time: Double, file: String, end: Double)
    case afterMediaEnd(option: String, time: Double, file: String, end: Double)
    case nonPositiveStep(step: Double)
    case emptyRange(from: Double, to: Double)
    case sampledList
    case noSound(file: String)
    case beforeSoundStart(option: String, time: Double)
    case atOrAfterSoundEnd(option: String, time: Double, end: Double)
    case afterSoundEnd(option: String, time: Double, end: Double)
    // `units` is how many units the title has, nil for a title not animated by unit.
    case unknownUnit(place: String, kind: String, unit: Int, units: Int?)

    // MARK: - Property
    var description: String {
        switch self {
        case let .missingMedia(file):
            "media \(quoted(file)) is not there"

        case let .noPicture(file):
            "media \(quoted(file)) is sound, so it has no picture to read"

        case let .notVideo(file, kind):
            "media \(quoted(file)) is \(kind == .audio ? "sound" : "an image"), and only a video has frames to follow"

        case let .timeOnImage(file):
            "media \(quoted(file)) is an image, whose one frame is at time 0, so it takes neither --at nor a range"

        case let .beforeMediaStart(option, time, file):
            "\(option): media second \(number(time)) is before the start of \(quoted(file))"

        case let .atOrAfterMediaEnd(option, time, file, end):
            "\(option): media second \(number(time)) is at or after the end of \(quoted(file)) at \(number(end))"

        case let .afterMediaEnd(option, time, file, end):
            "\(option): media second \(number(time)) is after the end of \(quoted(file)) at \(number(end))"

        case let .nonPositiveStep(step):
            "--step: the step must be at least a microsecond, found \(number(step))"

        case let .emptyRange(from, to):
            "--from: \(number(from)) is not before --to \(number(to))"

        case .sampledList:
            "the display list holds samples, an exposure in which an item has no one place, and the frame is reported as at its instant"

        case let .noSound(file):
            "media \(quoted(file)) has no sound to measure"

        case let .beforeSoundStart(option, time):
            "\(option): second \(number(time)) is before the start of the sound"

        case let .atOrAfterSoundEnd(option, time, end):
            "\(option): second \(number(time)) is at or after the end of the sound at \(number(end))"

        case let .afterSoundEnd(option, time, end):
            "\(option): second \(number(time)) is after the end of the sound at \(number(end))"

        case let .unknownUnit(place, kind, unit, units):
            "\(place) (\(kind)): the item draws unit \(unit) of the title, "
                + (units.map { $0 == 0 ? "which has no unit" : "whose units are 0 to \($0 - 1)" } ?? "which is not animated by unit")
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
}
