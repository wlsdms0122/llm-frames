//
//  MediaArgument.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import Foundation

// The medium a command that reads media at media times is given (FRAMES-23): a directory is an image sequence, read at
// the rate `--fps` gives it, since its files hold none, and any other path a file, which holds its own rate and takes
// no `--fps`.
package enum MediaArgument: Equatable, Sendable {
    case file(String)
    case imageSequence(directory: String, fps: Double)

    // MARK: - Property
    // MARK: - Initializer
    package init(
        path: String,
        fps: Double?
    ) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            guard fps == nil else { throw AnalysisError.rateOfFile(file: path) }

            self = .file(path)
            return
        }
        guard let fps else { throw AnalysisError.imageSequenceWithoutRate(directory: path) }

        self = .imageSequence(directory: path, fps: fps)
    }

    // MARK: - Public
    // MARK: - Private
}
