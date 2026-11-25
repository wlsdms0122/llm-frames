//
//  RecordingDecoder.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

// Gives each file the colour reading `colorReading` names and every picture as the bitmap of its frame index, a region
// of a page as that of frame 0, and every page a size of `pageSize`. A picture read other than tagged and every region
// of a page read are recorded. A check of pictures read in no colour space refuses a `platform` reading, as a decoder
// refuses a picture no fixed formula converts.
struct RecordingDecoder: MediaDecoder {
    // MARK: - Property
    let log: RoleCallLog
    let refuses: Bool
    let colorReading: ColorReading
    let pageSize: Size

    // MARK: - Initializer
    init(
        log: RoleCallLog,
        refuses: Bool = false,
        colorReading: ColorReading = .formulas(.srgb),
        pageSize: Size = Size(width: 1, height: 1)
    ) {
        self.log = log
        self.refuses = refuses
        self.colorReading = colorReading
        self.pageSize = pageSize
    }

    // MARK: - Lifecycle
    var largestPictureSide: Int {
        16_384
    }

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

    func picture(
        of file: MediaFile,
        region: PageRegion,
        scale: Double,
        reading: PictureReading
    ) throws -> Bitmap {
        log.record(.readPage(path: file.path, page: file.page, region: region, scale: scale, reading: reading))

        return Bitmap(frame: 0)
    }

    func pageSize(of file: MediaFile) throws -> Size {
        pageSize
    }

    func colorReading(of file: MediaFile) throws -> ColorReading {
        colorReading
    }

    func check(
        _ file: MediaFile,
        reading: PictureReading?
    ) throws {
        log.record(.checkMedia(path: file.path))
        guard !refuses else { throw RoleRefusal.decoder }
        if let reading, reading.colorSpace == nil, colorReading == .platform { throw RoleRefusal.decoder }
    }

    func sound(
        of file: MediaFile,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        log.record(.readSound(path: file.path, from: start, to: end))

        return SoundBuffer(sampleRate: 48_000, channels: 2, samples: [])
    }

    // Reports no medium and no time, as a run's report of it would be empty.
    func readings() -> MediaReadings {
        MediaReadings(media: [], seconds: StageTimes())
    }

    // MARK: - Public
    // MARK: - Private
}
