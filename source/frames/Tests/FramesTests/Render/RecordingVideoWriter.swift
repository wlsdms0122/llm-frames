//
//  RecordingVideoWriter.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

struct RecordingVideoWriter: VideoWriter {
    // MARK: - Property
    let path: String
    let log: RoleCallLog

    // MARK: - Initializer
    init(
        path: String,
        log: RoleCallLog
    ) {
        self.path = path
        self.log = log
    }

    // MARK: - Lifecycle
    func append(_ frame: Bitmap) throws {
        log.record(.append(path: path, frame: frame.frame))
    }

    func finish() throws {
        log.record(.finish(path: path))
    }

    // MARK: - Public
    // MARK: - Private
}
