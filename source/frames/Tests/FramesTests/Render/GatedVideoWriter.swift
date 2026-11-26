//
//  GatedVideoWriter.swift
//  FramesTests
//
//  Created by JSilver on 11/26/26.
//

import Foundation

@testable import Frames

// Writes each frame once its gate is opened for it, so a frame stays being written until the test lets it end.
struct GatedVideoWriter: VideoWriter {
    // MARK: - Property
    private let gate: DispatchSemaphore

    // A file it never writes, in no time.
    var encoding: FileEncoding {
        FileEncoding(path: "", codec: "ProRes 422 HQ", usesHardware: false, device: .cpu, seconds: StageTimes())
    }

    // MARK: - Initializer
    init(gate: DispatchSemaphore) {
        self.gate = gate
    }

    // MARK: - Lifecycle
    func append(_ frame: Pixels) throws {
        gate.wait()
    }

    func finish() throws { }

    // MARK: - Public
    // MARK: - Private
}
