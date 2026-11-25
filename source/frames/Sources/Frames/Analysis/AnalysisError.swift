//
//  AnalysisError.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

enum AnalysisError: Error, Equatable, CustomStringConvertible, Sendable {
    case missingMedia(file: String)
    case unreadableMedia(file: String, reason: String)
    case noPicture(file: String)
    case notVideo(file: String, kind: MediaKind)
    case targetNotFollowed(option: String, time: Double, file: String)
    case quadForm
    case quadNotConvex
    case timeOnStill(file: String)
    case beforeMediaStart(option: String, time: Double, file: String)
    case atOrAfterMediaEnd(option: String, time: Double, file: String, end: Double)
    case afterMediaEnd(option: String, time: Double, file: String, end: Double)
    case nonPositiveStep(step: Double)
    case emptyRange(from: Double, to: Double)
    case pageOfNonPDF(file: String, page: Int)
    case missingPage(file: String, page: Int, pageCount: Int)
    case unnamedPage(file: String, pageCount: Int)
    case highDynamicRangePage(file: String, page: Int, colorSpace: ColorSpace)
    case sampledList
    case noSound(file: String)
    case beforeSoundStart(option: String, time: Double)
    case atOrAfterSoundEnd(option: String, time: Double, end: Double)
    case afterSoundEnd(option: String, time: Double, end: Double)
    // `units` is how many units the title has, nil for a title not animated by unit.
    case unknownUnit(place: String, kind: String, unit: Int, units: Int?)
    case imageSequenceWithoutRate(directory: String)
    case rateOfFile(file: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .missingMedia(file):
            "media \(quoted(file)) is not there"

        case let .unreadableMedia(file, reason):
            "media \(quoted(file)) cannot be probed: \(reason)"

        case let .noPicture(file):
            "media \(quoted(file)) is sound, so it has no picture to read"

        case let .notVideo(file, kind):
            "media \(quoted(file)) is \(kind == .audio ? "sound" : "a still"), and only a video or an image sequence "
                + "has frames to follow"

        case let .targetNotFollowed(option, time, file):
            "\(option): the tracker follows the target on no frame of \(quoted(file)) from media second "
                + "\(number(time)), since none of it lies inside the picture or the tracker loses it there"

        case .quadForm:
            "--quad: a quadrilateral is four points [x, y] of numbers, its top left, top right, bottom right and bottom "
                + "left corners"

        case .quadNotConvex:
            "--quad: the quadrilateral is not strictly convex, so it is no plane to follow"

        case let .timeOnStill(file):
            "media \(quoted(file)) is a still, whose one picture is at time 0, so it takes neither --at nor a range"

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

        case let .pageOfNonPDF(file, page):
            "--page: media \(quoted(file)) is not a PDF, so it has no page \(page)"

        case let .missingPage(file, page, pageCount):
            "--page: media \(quoted(file)) has \(pageCount) \(pageCount == 1 ? "page" : "pages"), so it has no "
                + "page \(page)"

        case let .unnamedPage(file, pageCount):
            "media \(quoted(file)) is a PDF of \(pageCount) pages, more than one picture, so --page names the page"

        case let .highDynamicRangePage(file, page, colorSpace):
            "--color-space: media \(quoted(file)) page \(page) is not HDR, so it is read in a colour space of standard "
                + "dynamic range, not \(quoted(colorSpace.rawValue)). Allowed: "
                + VocabularyTable.standardDynamicRangeColorSpaces.joined(separator: ", ")

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

        case let .imageSequenceWithoutRate(directory):
            "media \(quoted(directory)) is an image sequence, whose files give no rate, so --fps gives it, as its "
                + "media form's fps does"

        case let .rateOfFile(file):
            "--fps: media \(quoted(file)) is no image sequence directory, and a file gives its own rate"
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
