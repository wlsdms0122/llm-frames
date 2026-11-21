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

    // MARK: - Property
    var description: String {
        switch self {
        case let .missingMedia(file):
            "media \(quoted(file)) is not there"

        case let .noPicture(file):
            "media \(quoted(file)) is sound, so it has no picture to read"

        case let .notVideo(file, kind):
            "media \(quoted(file)) is \(kind == .audio ? "sound" : "a still"), and only a video has frames to follow"

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
