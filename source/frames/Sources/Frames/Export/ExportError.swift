//
//  ExportError.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

package enum ExportError: Error, Equatable, CustomStringConvertible, Sendable {
    case timelessDocument(kind: String)
    case missingMedia(path: String)
    case notVideo(path: String, kind: MediaKind)
    case noTime
    case timeOutside(option: String, time: Double, end: Double, kind: String)
    case endPastEnd(time: Double, end: Double, kind: String)
    case emptyRange(from: Double, to: Double)
    case nonPositiveStep(Double)
    case nonPositiveColumns(Int)
    case outputExtension(path: String)
    case unwritableDirectory(path: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .timelessDocument(kind):
            "\(kind) documents have no sequence times, so they have no frames to take"

        case let .missingMedia(path):
            "\(quoted(path)): there is no such file"

        case let .notVideo(path, kind):
            "\(quoted(path)): the file is \(kind.rawValue), and frames are taken from a video or a document"

        case .noTime:
            "--at: no time is given"

        case let .timeOutside(option, time, end, kind):
            "\(option) \(written(time)): the \(kind) has no frame then, since it runs over [0, \(written(end)))"

        case let .endPastEnd(time, end, kind):
            "--to \(written(time)): past the end of the \(kind) at \(written(end))"

        case let .emptyRange(from, to):
            "--from \(written(from)) --to \(written(to)): the range holds no time, since --from is not before --to"

        case let .nonPositiveStep(step):
            "--step \(written(step)): a step is at least one microsecond long, or the range never ends"

        case let .nonPositiveColumns(columns):
            "--cols \(columns): a sheet has at least one column"

        case let .outputExtension(path):
            "\(quoted(path)): frames are drawn to a .png file"

        case let .unwritableDirectory(path):
            "\(quoted(path)): the directory for the frames cannot be made there"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }

    private func written(_ time: Double) -> String {
        JSONValue.time(time).written
    }
}
