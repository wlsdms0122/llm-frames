//
//  MediaFactTable.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames

// A fake probe: the facts of each file and the frame files of each image sequence directory, in natural order, whose
// frames are all `imageSequenceSize`, and the pages of each PDF in `pages`, in page order. A file or directory in
// `failures` is there but cannot be read, for that reason.
struct MediaFactTable: MediaFactProvider {
    // MARK: - Property
    let files: [String: ProbedMedia]
    let imageSequences: [String: [String]]
    let pages: [String: [Size]]
    let failures: [String: ProbeFailure]
    let imageSequenceSize = Size(width: 1080, height: 1920)

    // MARK: - Initializer
    init(
        files: [String: ProbedMedia],
        imageSequences: [String: [String]] = [:],
        pages: [String: [Size]] = [:],
        failures: [String: ProbeFailure] = [:]
    ) {
        self.files = files
        self.imageSequences = imageSequences
        self.pages = pages
        self.failures = failures
    }

    // MARK: - Public
    func probedMedium(of file: String) throws -> ProbedMedium? {
        if let failure = failures[file] { throw failure }
        if let sizes = pages[file] { return .pdf(pageCount: sizes.count) }

        return files[file].map(ProbedMedium.media)
    }

    func probedImageSequence(at directory: String) throws -> ProbedImageSequence? {
        if let failure = failures[directory] { throw failure }

        return imageSequences[directory].map { ProbedImageSequence(files: $0, size: imageSequenceSize) }
    }

    func probedPage(
        _ page: Int,
        of file: String
    ) throws -> ProbedPage? {
        if let failure = failures[file] { throw failure }
        guard let sizes = pages[file] else { return nil }
        guard sizes.indices.contains(page - 1) else { throw ProbeFailure("media \(file) has no page \(page)") }

        return ProbedPage(size: sizes[page - 1], pageCount: sizes.count)
    }

    // MARK: - Private
}
