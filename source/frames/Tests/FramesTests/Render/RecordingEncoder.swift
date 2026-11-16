//
//  RecordingEncoder.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

struct RecordingEncoder: Encoder {
    // MARK: - Property
    let log: RoleCallLog
    let refuses: Bool

    // MARK: - Initializer
    init(
        log: RoleCallLog,
        refuses: Bool = false
    ) {
        self.log = log
        self.refuses = refuses
    }

    // MARK: - Lifecycle
    func check(_ target: EncodeTarget) throws {
        log.record(.checkTarget(target))
        guard !refuses else { throw RoleRefusal.encoder }
    }

    func writeImage(
        _ bitmap: Bitmap,
        to path: String
    ) throws {
        log.record(.writeImage(path: path, frame: bitmap.frame))
    }

    func videoWriter(
        for target: EncodeTarget,
        size: Size,
        fps: Double,
        sound: SoundBuffer?
    ) throws -> any VideoWriter {
        log.record(.videoWriter(target, size: size, fps: fps, sound: sound))

        switch target {
        case let .master(path, _), let .delivery(path):
            return RecordingVideoWriter(path: path, log: log)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
