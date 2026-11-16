//
//  MediaFactTable.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames

// A fake probe: the facts of each file and the frame files of each image sequence directory, in natural order, whose
// frames are all `imageSequenceSize`.
struct MediaFactTable: MediaFactProvider {
    // MARK: - Property
    let files: [String: ProbedMedia]
    let imageSequences: [String: [String]]
    let imageSequenceSize = Size(width: 1080, height: 1920)

    // MARK: - Initializer
    init(
        files: [String: ProbedMedia],
        imageSequences: [String: [String]] = [:]
    ) {
        self.files = files
        self.imageSequences = imageSequences
    }

    // MARK: - Public
    func probedMedia(of file: String) -> ProbedMedia? {
        files[file]
    }

    func probedImageSequence(at directory: String) -> ProbedImageSequence? {
        imageSequences[directory].map { ProbedImageSequence(files: $0, size: imageSequenceSize) }
    }

    // MARK: - Private
}
