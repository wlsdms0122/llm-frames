//
//  FailingVideoWriter.swift
//  FramesTests
//
//  Created by JSilver on 11/24/26.
//

@testable import Frames

// Refuses every frame.
struct FailingVideoWriter: VideoWriter {
    enum Failure: Error, Equatable {
        case refused
    }

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Lifecycle
    // A file it never writes, in no time.
    var encoding: FileEncoding {
        FileEncoding(path: "", codec: "ProRes 422 HQ", usesHardware: false, seconds: StageTimes())
    }

    func append(_ frame: Bitmap) throws {
        throw Failure.refused
    }

    func finish() throws { }

    // MARK: - Public
    // MARK: - Private
}
