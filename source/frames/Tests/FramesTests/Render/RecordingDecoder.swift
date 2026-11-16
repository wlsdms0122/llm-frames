//
//  RecordingDecoder.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

struct RecordingDecoder: MediaDecoder {
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
    func picture(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> Bitmap {
        Bitmap(frame: index)
    }

    func check(_ file: MediaFile) throws {
        log.record(.checkMedia(path: file.path))
        guard !refuses else { throw RoleRefusal.decoder }
    }

    func sound(
        of file: String,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        SoundBuffer(sampleRate: 48_000, channels: 2, samples: [])
    }

    // MARK: - Public
    // MARK: - Private
}
