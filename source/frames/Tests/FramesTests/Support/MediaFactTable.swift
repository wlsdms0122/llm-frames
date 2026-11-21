//
//  MediaFactTable.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames

// A fake probe: the facts of each file, the frame files of each image sequence directory, in natural order, whose
// frames are all `imageSequenceSize`, and the page count of each PDF. A file or directory in `failures` is there but
// cannot be read, for that reason.
struct MediaFactTable: MediaFactProvider {
    // MARK: - Property
    let files: [String: ProbedMedia]
    let imageSequences: [String: [String]]
    let pageCounts: [String: Int]
    let failures: [String: ProbeFailure]
    let imageSequenceSize = Size(width: 1080, height: 1920)

    // MARK: - Initializer
    init(
        files: [String: ProbedMedia],
        imageSequences: [String: [String]] = [:],
        pageCounts: [String: Int] = [:],
        failures: [String: ProbeFailure] = [:]
    ) {
        self.files = files
        self.imageSequences = imageSequences
        self.pageCounts = pageCounts
        self.failures = failures
    }

    // MARK: - Public
    func probedMedia(of file: String) throws -> ProbedMedia? {
        if let failure = failures[file] { throw failure }

        return files[file]
    }

    func probedImageSequence(at directory: String) throws -> ProbedImageSequence? {
        if let failure = failures[directory] { throw failure }

        return imageSequences[directory].map { ProbedImageSequence(files: $0, size: imageSequenceSize) }
    }

    func pageCount(of file: String) -> Int? {
        pageCounts[file]
    }

    // MARK: - Private
}
