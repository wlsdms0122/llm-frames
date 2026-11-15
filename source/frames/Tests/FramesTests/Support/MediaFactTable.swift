//
//  MediaFactTable.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames

// A fake probe: the facts of each file and the number of frames in each image sequence directory.
struct MediaFactTable: MediaFactProvider {
    // MARK: - Property
    let files: [String: ProbedMedia]
    let imageSequences: [String: Int]

    // MARK: - Initializer
    init(
        files: [String: ProbedMedia],
        imageSequences: [String: Int] = [:]
    ) {
        self.files = files
        self.imageSequences = imageSequences
    }

    // MARK: - Public
    func probedMedia(of file: String) -> ProbedMedia? {
        files[file]
    }

    func frameCount(ofImageSequence directory: String) -> Int? {
        imageSequences[directory]
    }

    // MARK: - Private
}
