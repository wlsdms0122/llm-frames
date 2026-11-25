//
//  RecordingVideoWriter.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation

@testable import Frames

// Records each call. With `writesFile` it writes `RecordingEncoder.writtenByteCount` zero bytes at its path when it
// finishes.
struct RecordingVideoWriter: VideoWriter {
    // MARK: - Property
    let path: String
    let log: RoleCallLog
    let writesFile: Bool

    // MARK: - Initializer
    init(
        path: String,
        log: RoleCallLog,
        writesFile: Bool = false
    ) {
        self.path = path
        self.log = log
        self.writesFile = writesFile
    }

    // MARK: - Lifecycle
    // Written as `ProRes 422 HQ` on the processor, in no time.
    var encoding: FileEncoding {
        FileEncoding(path: path, codec: "ProRes 422 HQ", usesHardware: false, seconds: StageTimes())
    }

    func append(_ frame: Pixels) throws {
        log.record(.append(path: path, frame: frame.bitmap.frame))
    }

    func finish() throws {
        log.record(.finish(path: path))
        guard writesFile else { return }

        try Self.write(path, log: log)
    }

    // MARK: - Public
    // Writes the bytes a recording encoder writes, recording `replace` first when a file is already at `path`.
    static func write(
        _ path: String,
        log: RoleCallLog
    ) throws {
        if FileManager.default.fileExists(atPath: path) {
            log.record(.replace(path: path))
        }
        try Data(count: RecordingEncoder.writtenByteCount).write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Private
}
