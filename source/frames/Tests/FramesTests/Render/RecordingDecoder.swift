//
//  RecordingDecoder.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

// Gives each file the colour reading `colorReading` names and every picture as the bitmap of its frame index. A picture
// read other than tagged is recorded.
struct RecordingDecoder: MediaDecoder {
    // MARK: - Property
    let log: RoleCallLog
    let refuses: Bool
    let colorReading: ColorReading

    // MARK: - Initializer
    init(
        log: RoleCallLog,
        refuses: Bool = false,
        colorReading: ColorReading = .formulas(.srgb)
    ) {
        self.log = log
        self.refuses = refuses
        self.colorReading = colorReading
    }

    // MARK: - Lifecycle
    func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Bitmap {
        if reading != .tagged {
            log.record(.readPicture(path: file.path, frame: index, reading: reading))
        }

        return Bitmap(frame: index)
    }

    func colorReading(of file: MediaFile) throws -> ColorReading {
        colorReading
    }

    func check(_ file: MediaFile) throws {
        log.record(.checkMedia(path: file.path))
        guard !refuses else { throw RoleRefusal.decoder }
    }

    func sound(
        of file: MediaFile,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        log.record(.readSound(path: file.path, from: start, to: end))

        return SoundBuffer(sampleRate: 48_000, channels: 2, samples: [])
    }

    // MARK: - Public
    // MARK: - Private
}
