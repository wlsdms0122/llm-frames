//
//  TranscodeError.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

package enum TranscodeError: Error, Equatable, CustomStringConvertible, Sendable {
    case maximumSide(Int)
    case missingInput(path: String)
    case unsupportedInput(path: String)
    case sameFile(path: String)
    case outputDirectory(path: String)
    case outputExtension(path: String, input: String, kind: MediaKind, allowed: [String])
    case codecWithoutVideo(path: String)
    case noSound(path: String, input: String)
    case noFrameRate(path: String)
    case undersizedVideo(path: String, maximumSide: Int?, size: Size)
    case unremovable(path: String, reason: String)
    case unmeasurable(path: String)

    // MARK: - Property
    package var description: String {
        switch self {
        case let .maximumSide(value):
            "--max takes a positive number of pixels, not \(value)"

        case let .missingInput(path):
            "\(quoted(path)): no such file"

        case let .unsupportedInput(path):
            "\(quoted(path)): transcode takes an image, a sound or a video file"

        case let .sameFile(path):
            "\(quoted(path)): the output is the input file, which transcode does not write over"

        case let .outputDirectory(path):
            "\(quoted(path)): the output is a directory"

        case let .outputExtension(path, input, kind, allowed):
            "\(quoted(path)): \(quoted(input)) is \(article(of: kind)), which transcodes to \(listed(allowed)) files"

        case let .codecWithoutVideo(path):
            "\(quoted(path)): --codec picks the codec of a video output, and this output is not a video"

        case let .noSound(path, input):
            "\(quoted(path)): \(quoted(input)) has no sound track to write to an .m4a file"

        case let .noFrameRate(path):
            "\(quoted(path)): the video has no frame rate to write its frames at"

        case let .undersizedVideo(path, maximumSide, size):
            "\(quoted(path)): \(maximumSide.map { "--max \($0) makes" } ?? "the source is") the video "
                + "\(Int(size.width))x\(Int(size.height)), and a video's sides are at least 2 pixels"

        case let .unremovable(path, reason):
            "\(quoted(path)): the existing file cannot be removed: \(reason)"

        case let .unmeasurable(path):
            "\(quoted(path)): its size cannot be read"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }

    private func article(of kind: MediaKind) -> String {
        switch kind {
        case .image:
            "an image"

        case .audio:
            "a sound"

        case .video:
            "a video"

        case .sequence:
            "an image sequence"
        }
    }

    // `.jpg, .heic or .png`.
    private func listed(_ extensions: [String]) -> String {
        let written = extensions.map { ".\($0)" }
        guard let last = written.last, written.count > 1 else { return written.first ?? "no" }

        return written.dropLast().joined(separator: ", ") + " or " + last
    }
}
