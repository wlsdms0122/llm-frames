//
//  RecordingEncoder.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation

@testable import Frames

// Records each call. An image, a sound file or a compressed video it writes is `writtenByteCount` zero bytes at the
// target's path, and a write that finds a file already there records `replace` first.
struct RecordingEncoder: Encoder {
    // MARK: - Property
    static let writtenByteCount = 10

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

    func check(_ target: ImageTarget) throws {
        log.record(.checkImageTarget(target))
        guard !refuses else { throw RoleRefusal.encoder }
    }

    func check(_ target: SoundTarget) throws {
        log.record(.checkSoundTarget(target))
        guard !refuses else { throw RoleRefusal.encoder }
    }

    func writeAnalysisPicture(
        of frame: Bitmap,
        in output: ColorConversion,
        to path: String
    ) throws {
        log.record(.writeAnalysisPicture(path: path, frame: frame.frame, output: output))
    }

    func writeImage(
        _ bitmap: Bitmap,
        for target: ImageTarget
    ) throws -> FileEncoding {
        log.record(.writeImageTarget(target, frame: bitmap.frame))
        try RecordingVideoWriter.write(target.path, log: log)

        return FileEncoding(path: target.path, codec: "PNG", usesHardware: false, device: .cpu, seconds: StageTimes())
    }

    func writeSound(
        _ sound: SoundBuffer,
        for target: SoundTarget
    ) throws {
        log.record(.writeSound(target, sound: sound))
        try RecordingVideoWriter.write(target.path, log: log)
    }

    func videoWriter(
        for target: EncodeTarget,
        size: Size,
        fps: Double,
        sound: SoundBuffer?
    ) throws -> any VideoWriter {
        log.record(.videoWriter(target, size: size, fps: fps, sound: sound))

        switch target {
        case let .master(path, _, _), let .delivery(path, _):
            return RecordingVideoWriter(path: path, log: log)

        case let .compressed(path, _, _, _, _):
            return RecordingVideoWriter(path: path, log: log, writesFile: true)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
