//
//  AVFoundationDecoder.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import CoreImage
import Foundation
import Frames
import os

// The `avfoundation` decoder: probes media files and image sequence directories, and reads their frames by index as
// working values or analysis pictures, and their sound. A still is read with ImageIO, its orientation applied, and a
// video with AVFoundation, its preferred transform applied. Each takes its samples as the file stores them and converts
// their colour by the fixed formulas of FRAMES-26: in the colour space a reading names, or the one its tags name. A
// `platform` reading instead converts the picture from its file's colour by Core Image's colour management. A page of a
// PDF is checked and drawn by `PageReader`. A video, a sound track and a PDF are loaded once and kept, and a video read
// forward has its next frame read ahead by `PictureLookahead`. It keeps a reader open on the 48 videos read last, and
// closes the reader of a video read longer ago. Made to convert on the GPU, on a machine with a Metal device, it takes
// a video's frames read as working values to a surface by `MetalPictureConverter` wherever the conversion's steps and
// the frame's placement allow, and every other picture on the CPU (FRAMES-21 Pictures). The largest picture it holds is
// 16384 pixels on a side.
// It times its reading of pictures and sound as `decode` and its conversion of them as `workingConversion`, that of a
// frame read ahead apart as well, and tallies how it read each medium: a frame read ahead is decoded where it is read,
// and read only when it is given (FRAMES-23 Runs). A page's draw is `decode` whole, any colour conversion included,
// that of Core Graphics and that of a written `colorSpace` alike (FRAMES-21).
package final class AVFoundationDecoder: Sendable {
    // MARK: - Property
    // The most pixels on a side of a picture this decoder holds: a frame, a still or a region of a page.
    package let largestPictureSide = 16_384

    private let converter = PictureConverter()
    // Nil for a decoder made to convert on the CPU, and on a machine with no Metal device.
    private let metal: MetalPictureConverter?
    private let managedConverter = ManagedPictureConverter()
    // The most videos the decoder keeps a reader open on. AVFoundation decodes no frame for a 65th reader decoding at
    // once in one process (FRAMES-21 Notes), and a video read by one of the reads ahead and callers at once may open a
    // reader past this count.
    private static let openReaders = 48

    private let lookahead = PictureLookahead()
    private let videos = OSAllocatedUnfairLock<[String: VideoReader]>(initialState: [:])
    // The videos a frame was read from, read longest ago first, of which only the last `openReaders` keep a reader.
    private let readOrder = OSAllocatedUnfairLock<[String]>(initialState: [])
    private let sounds = OSAllocatedUnfairLock<[String: SoundReader]>(initialState: [:])
    private let documents = OSAllocatedUnfairLock<[String: PageReader]>(initialState: [:])
    // The stages run on a caller's thread, and those run on the lookahead's threads reading ahead.
    private let clock = StageClock(marker: StageSignposter())
    private let aheadClock = StageClock(marker: StageSignposter())
    private let tallies = OSAllocatedUnfairLock<[ReadingKey: ReadingTally]>(initialState: [:])

    // MARK: - Initializer
    // `conversion` is the processor a video's working values are converted on wherever the GPU runs their conversion;
    // every other picture is converted on the CPU.
    package init(conversion: ConversionDevice = .gpu) {
        metal = conversion == .gpu ? MetalPictureConverter() : nil
    }

    // MARK: - Public
    // MARK: - Private
    private func video(at path: String) throws -> VideoReader? {
        if let video = videos.withLock({ $0[path] }) { return video }
        guard let video = try VideoReader(path: path) else { return nil }
        videos.withLock { $0[path] = video }

        return video
    }

    // Counts the video at `path` read last, and closes the reader of each video read longer ago than the last
    // `openReaders`, holding no video's lock while it does.
    private func recordRead(of path: String) {
        let closing = readOrder.withLock { order -> [String] in
            order.removeAll { $0 == path }
            order.append(path)
            let closing = Array(order.prefix(max(order.count - Self.openReaders, 0)))
            order.removeFirst(closing.count)

            return closing
        }
        let readers = videos.withLock { videos in closing.compactMap { videos[$0] } }
        for reader in readers {
            reader.close()
        }
    }

    // Nil for a file that is no PDF.
    private func document(at path: String) throws -> PageReader? {
        if let document = documents.withLock({ $0[path] }) { return document }
        guard let document = try PageReader(path: path) else { return nil }
        documents.withLock { $0[path] = document }

        return document
    }

    // The PDF of a file that names a page.
    private func document(of file: MediaFile) throws -> (PageReader, Int)? {
        guard let page = file.page else { return nil }
        guard let document = try document(at: file.path) else { throw DecoderError.noDocument(file: file.path) }

        return (document, page)
    }

    // A picture larger than the decoder holds stops, naming its size.
    private func checkSize(
        _ size: Size,
        path: String
    ) throws {
        let (width, height) = (Int(size.width.rounded()), Int(size.height.rounded()))
        guard max(width, height) <= largestPictureSide else {
            throw DecoderError.pictureSize(file: path, width: width, height: height, largest: largestPictureSide)
        }
    }

    // Nil for a file without a sound track.
    private func soundTrack(at path: String) throws -> SoundReader? {
        if let sound = sounds.withLock({ $0[path] }) { return sound }
        guard let sound = try SoundReader(path: path) else { return nil }
        sounds.withLock { $0[path] = sound }

        return sound
    }

    private func probedSound(at path: String) throws -> ProbedSound? {
        try soundTrack(at: path).map { ProbedSound(channels: $0.layout.labels.count, sampleRate: $0.sampleRate) }
    }

    // `path` is the still's file, the frame's of an image sequence, and `file` the medium it belongs to.
    private func picture(
        of still: StillReader,
        path: String,
        in file: MediaFile,
        reading: PictureReading
    ) throws -> Bitmap {
        let tagged = try still.taggedColor(path: path)
        if case .platform = reading {
            let image = try clock.measure(.decode) { try still.taggedImage(path: path) }

            return try picture(from: image, tagged: tagged, path: path, reading: reading, clock: clock).picture
        }

        let (image, pixelFormat) = try clock.measure(.decode) { try still.image(path: path) }
        let (picture, conversion) = try picture(from: image, tagged: tagged, path: path, reading: reading, clock: clock)
        record(
            file,
            conversion: conversion,
            device: .cpu,
            pixelFormat: pixelFormat,
            read: 1,
            decoded: 1,
            reopened: false,
            readFile: path
        )

        return picture
    }

    // `read` pictures of `file` given and `decoded` decoded by `conversion` on `device`, nil for a `platform` reading,
    // which only `transcode` makes and no run reports. A video's reader opened again is `reopened`, and a still's or a
    // frame's file read again is `readFile` read before.
    private func record(
        _ file: MediaFile,
        conversion: WorkingConversion?,
        device: ConversionDevice,
        pixelFormat: String,
        read: Int,
        decoded: Int,
        reopened: Bool,
        readFile: String?
    ) {
        guard let conversion else { return }

        tallies.withLock { tallies in
            let key = ReadingKey(path: file.path, page: file.page, conversion: conversion, device: device)
            var tally = tallies[key] ?? ReadingTally(order: tallies.count, pixelFormat: pixelFormat)
            tally.pixelFormat = pixelFormat
            tally.framesRead += read
            tally.framesDecoded += decoded
            if reopened { tally.reopened += 1 }
            if let readFile, !tally.filesRead.insert(readFile).inserted { tally.reopened += 1 }
            tallies[key] = tally
        }
    }

    // `image` is the picture with no colour matched, or tagged with its file's colour for a `platform` reading.
    // `tagged` is the file's colour, which a reading that names a colour space overrides, and its mastering display's
    // peak, which an HDR picture is tone mapped from either way. With the picture comes the form it was converted by,
    // nil for a `platform` reading. `clock` times the conversion on the thread that runs it.
    private func picture(
        from image: CIImage,
        tagged: TaggedColor,
        path: String,
        reading: PictureReading,
        clock: StageClock
    ) throws -> (picture: Bitmap, conversion: WorkingConversion?) {
        switch reading {
        case let .working(colorSpace, targetPeak):
            let conversion = try conversion(in: colorSpace, tagged: tagged, path: path)
            let toneMapping = targetPeak.flatMap {
                conversion.toneMapping(masteringDisplayPeak: tagged.masteringDisplayPeak, targetPeak: $0)
            }
            let picture = clock.measure(.workingConversion) {
                converter.picture(from: image, conversion: conversion, toneMapping: toneMapping)
            }
            return (picture, conversion.workingConversion)

        case let .analysis(colorSpace):
            let conversion = try conversion(in: colorSpace, tagged: tagged, path: path)
            let toneMapping = conversion.toneMapping(
                masteringDisplayPeak: tagged.masteringDisplayPeak,
                targetPeak: ColorSpace.srgb.peakLuminance
            )
            let picture = clock.measure(.workingConversion) {
                converter.analysisPicture(from: image, conversion: conversion, toneMapping: toneMapping)
            }
            return (picture, conversion.workingConversion)

        case let .platform(colorSpace):
            return (clock.measure(.workingConversion) { managedConverter.picture(from: image, in: colorSpace) }, nil)
        }
    }

    // A video frame's working values converted on the GPU, with the form they were converted by: nil for a decoder that
    // converts on the CPU, for a reading other than `working`, and where the GPU does not run the conversion or the
    // frame's placement. Tone mapping is of HDR pictures alone, whose steps are `formulas`, so a target peak changes
    // nothing here.
    private func surface(
        of buffer: CVImageBuffer,
        in video: VideoReader,
        tagged: TaggedColor,
        path: String,
        reading: PictureReading,
        clock: StageClock
    ) throws -> (picture: PictureSurface, conversion: WorkingConversion)? {
        guard let metal, case let .working(colorSpace, _) = reading else { return nil }
        let conversion = try conversion(in: colorSpace, tagged: tagged, path: path)
        if case .formulas = conversion.steps { return nil }

        let surface = clock.measure(.workingConversion) {
            metal.picture(
                from: buffer,
                storedSize: video.storedSize,
                displaySize: video.displaySize,
                transform: video.transform,
                steps: conversion.steps
            )
        }

        return surface.map { ($0, conversion.workingConversion) }
    }

    // The form a picture read by `reading` is converted by, nil for a `platform` reading.
    private func workingConversion(
        of reading: PictureReading,
        tagged: TaggedColor,
        path: String
    ) throws -> WorkingConversion? {
        if case .platform = reading { return nil }

        return try conversion(in: reading.colorSpace, tagged: tagged, path: path).workingConversion
    }

    // The conversion from `colorSpace` where a reading names one, else from the file's tagged colour.
    private func conversion(
        in colorSpace: ColorSpace?,
        tagged: TaggedColor,
        path: String
    ) throws -> MediaColorConversion {
        if let colorSpace { return MediaColorConversion(.space(colorSpace)) }

        do {
            return MediaColorConversion(try tagged.color.get())
        } catch {
            throw DecoderError.unconvertibleColor(file: path, reason: error.reason)
        }
    }

    // A file's colour that no fixed formula converts in `colorSpace` stops, with the reason its tags give.
    private func checkColor(
        _ tagged: TaggedColor,
        in colorSpace: ColorSpace?,
        path: String
    ) throws {
        guard !tagged.colorReading.converts(in: colorSpace), case let .failure(refusal) = tagged.color else { return }

        throw DecoderError.unconvertibleColor(file: path, reason: refusal.reason)
    }

    // The PNG files in a directory in natural order, so `frame2` comes before `frame10`.
    private func frameFiles(in directory: String) throws -> [String] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            throw DecoderError.unreadable(file: directory)
        }

        return names
            .filter { ($0 as NSString).pathExtension.lowercased() == "png" }
            .sorted { $0.compare($1, options: [.numeric]) == .orderedAscending }
            .map { (directory as NSString).appendingPathComponent($0) }
    }
}

extension AVFoundationDecoder: MediaFactProvider {
    // MARK: - Lifecycle
    // A file is a PDF where it has a page count, and media of another kind by its facts otherwise.
    package func probedMedium(of file: String) throws -> ProbedMedium? {
        if let pageCount = try pageCount(of: file) { return .pdf(pageCount: pageCount) }

        return try probedMedia(of: file).map(ProbedMedium.media)
    }

    // The facts of a file that is no PDF. A PDF is read here as no media.
    package func probedMedia(of file: String) throws -> ProbedMedia? {
        guard FileManager.default.fileExists(atPath: file) else { return nil }
        if let still = try StillReader(path: file) {
            return ProbedMedia(
                kind: .image,
                size: still.displaySize,
                hasAlpha: still.hasAlpha,
                colorSpace: try still.taggedColor(path: file).probed
            )
        }
        if let video = try video(at: file) {
            return ProbedMedia(
                kind: .video,
                duration: video.duration,
                fps: video.fps,
                frames: video.frameTimes,
                size: video.displaySize,
                hasAlpha: video.hasAlpha,
                colorSpace: video.taggedColor.probed,
                sound: video.hasSound ? try probedSound(at: file) : nil
            )
        }

        // A file without a picture track is sound, or no media at all.
        guard let sound = try probedSound(at: file) else { throw DecoderError.unreadable(file: file) }
        let asset = AVURLAsset(url: URL(fileURLWithPath: file))
        let duration = try LoadWaiter(file: file).value(of: .duration, key: "duration", in: asset)

        return ProbedMedia(kind: .audio, duration: CMTimeGetSeconds(duration), sound: sound)
    }

    // Every frame is the same size, or the directory is not a sequence.
    package func probedImageSequence(at directory: String) throws -> ProbedImageSequence? {
        guard FileManager.default.fileExists(atPath: directory) else { return nil }
        let files = try frameFiles(in: directory)
        guard let first = files.first else { throw DecoderError.emptySequence(directory: directory) }
        guard let still = try StillReader(path: first) else { throw DecoderError.unreadable(file: first) }
        let size = still.displaySize

        for file in files.dropFirst() {
            guard let frameSize = try StillReader(path: file)?.displaySize else {
                throw DecoderError.unreadable(file: file)
            }
            guard frameSize == size else { throw DecoderError.unequalFrame(file: file, size: frameSize, first: size) }
        }

        return ProbedImageSequence(
            files: files,
            size: size,
            hasAlpha: still.hasAlpha,
            colorSpace: try still.taggedColor(path: first).probed
        )
    }

    // The page count of `file` where it is a PDF, nil where it is not there or is no PDF. A PDF that opens only with a
    // password throws.
    package func pageCount(of file: String) throws -> Int? {
        guard FileManager.default.fileExists(atPath: file) else { return nil }

        return try document(at: file)?.pageCount
    }

    package func probedPage(
        _ page: Int,
        of file: String
    ) throws -> ProbedPage? {
        guard FileManager.default.fileExists(atPath: file) else { return nil }
        guard let document = try document(at: file) else { throw DecoderError.noDocument(file: file) }

        return try document.probed(page)
    }
}

extension AVFoundationDecoder: MediaDecoder {
    // MARK: - Lifecycle
    package func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Pixels {
        if let page = file.page { throw DecoderError.pageFrame(file: file.path, page: page) }
        if !file.frameFiles.isEmpty {
            guard file.frameFiles.indices.contains(index) else {
                throw DecoderError.noFrame(file: file.path, index: index, count: file.frameFiles.count)
            }

            let path = file.frameFiles[index]
            guard let still = try StillReader(path: path) else { throw DecoderError.unreadable(file: path) }
            try checkSize(still.displaySize, path: path)

            return .bitmap(try picture(of: still, path: path, in: file, reading: reading))
        }
        if let still = try StillReader(path: file.path) {
            guard index == 0 else { throw DecoderError.noFrame(file: file.path, index: index, count: 1) }
            try checkSize(still.displaySize, path: file.path)

            return .bitmap(try picture(of: still, path: file.path, in: file, reading: reading))
        }

        guard let video = try video(at: file.path) else { throw DecoderError.unreadable(file: file.path) }
        try checkSize(video.displaySize, path: file.path)
        let count = video.frames.count
        guard file.frameTimes.isEmpty || file.frameTimes.count == count else {
            throw DecoderError.frameCount(file: file.path, pinned: file.frameTimes.count, counted: count)
        }
        guard video.frames.indices.contains(index) else {
            throw DecoderError.noFrame(file: file.path, index: index, count: count)
        }

        try checkColor(video.taggedColor, in: reading.colorSpace, path: file.path)

        let path = file.path
        let tagged = video.taggedColor
        let picture = try lookahead.picture(
            atFrame: index,
            of: path,
            count: count,
            reading: reading
        ) { [self] index, isAhead in
            let clock = isAhead ? self.aheadClock : self.clock
            recordRead(of: path)
            if case .platform = reading {
                let image = try clock.measure(.decode) { try video.taggedImage(atFrame: index, path: path) }

                let (picture, _) = try picture(from: image, tagged: tagged, path: path, reading: reading, clock: clock)

                return .bitmap(picture)
            }

            let (buffer, decoded, reopened) = try clock.measure(.decode) {
                try video.buffer(atFrame: index, path: path)
            }
            let surface = try surface(of: buffer, in: video, tagged: tagged, path: path, reading: reading, clock: clock)
            if let surface {
                record(
                    file,
                    conversion: surface.conversion,
                    device: .gpu,
                    pixelFormat: VideoReader.pixelFormat,
                    read: 0,
                    decoded: decoded,
                    reopened: reopened,
                    readFile: nil
                )

                return .surface(surface.picture)
            }

            let (picture, conversion) = try picture(
                from: video.image(of: buffer),
                tagged: tagged,
                path: path,
                reading: reading,
                clock: clock
            )
            record(
                file,
                conversion: conversion,
                device: .cpu,
                pixelFormat: VideoReader.pixelFormat,
                read: 0,
                decoded: decoded,
                reopened: reopened,
                readFile: nil
            )

            return .bitmap(picture)
        }
        let device: ConversionDevice = switch picture {
        case .bitmap:
            .cpu

        case .surface:
            .gpu
        }
        record(
            file,
            conversion: try workingConversion(of: reading, tagged: tagged, path: path),
            device: device,
            pixelFormat: VideoReader.pixelFormat,
            read: 1,
            decoded: 0,
            reopened: false,
            readFile: nil
        )

        return picture
    }

    package func picture(
        of file: MediaFile,
        region: PageRegion,
        scale: Double,
        reading: PictureReading
    ) throws -> Pixels {
        guard let (document, page) = try document(of: file) else { throw DecoderError.unreadable(file: file.path) }
        guard region.width >= 1, region.height >= 1, scale > 0 else {
            throw DecoderError.pageRegion(file: file.path, region: region, scale: scale)
        }
        guard max(region.width, region.height) <= largestPictureSide else {
            throw DecoderError.pictureSize(
                file: file.path,
                width: region.width,
                height: region.height,
                largest: largestPictureSide
            )
        }

        let picture = try clock.measure(.decode) {
            try document.picture(page, region: region, scale: scale, reading: reading)
        }
        let conversion: WorkingConversion? = switch reading {
        case let .working(colorSpace, _), let .analysis(colorSpace):
            MediaColorConversion(.space(colorSpace ?? .srgb)).workingConversion

        case .platform:
            nil
        }
        record(
            file,
            conversion: conversion,
            device: .cpu,
            pixelFormat: PageReader.pixelFormat,
            read: 1,
            decoded: 1,
            reopened: false,
            readFile: nil
        )

        return .bitmap(picture)
    }

    package func pageSize(of file: MediaFile) throws -> Size {
        guard let (document, page) = try document(of: file) else { throw DecoderError.unreadable(file: file.path) }

        return try document.page(page).1.size
    }

    // A page's untagged colour is `srgb`, which a written colour space replaces.
    package func colorReading(of file: MediaFile) throws -> ColorReading {
        if try document(of: file) != nil { return .formulas(.srgb) }
        let path = file.frameFiles.first ?? file.path
        if let still = try StillReader(path: path) { return try still.taggedColor(path: path).colorReading }
        guard let video = try video(at: path) else { throw DecoderError.unreadable(file: path) }

        return video.taggedColor.colorReading
    }

    package func check(
        _ file: MediaFile,
        reading: PictureReading?
    ) throws {
        if let (document, page) = try document(of: file) {
            _ = try document.page(page)
            try document.check(page, reading: reading)

            return
        }

        // A nil reading reads only sound, so no colour is checked.
        if !file.frameFiles.isEmpty {
            for path in file.frameFiles {
                guard let still = try StillReader(path: path) else { throw DecoderError.unreadable(file: path) }
                try checkSize(still.displaySize, path: path)
                if let reading { try checkColor(try still.taggedColor(path: path), in: reading.colorSpace, path: path) }
            }

            return
        }
        if let still = try StillReader(path: file.path) {
            try checkSize(still.displaySize, path: file.path)
            if let reading {
                try checkColor(try still.taggedColor(path: file.path), in: reading.colorSpace, path: file.path)
            }

            return
        }

        // A file without a picture track is sound, or no media at all.
        guard let video = try video(at: file.path) else {
            guard (try? soundTrack(at: file.path)) != nil else { throw DecoderError.unreadable(file: file.path) }

            return
        }
        try checkSize(video.displaySize, path: file.path)
        guard file.frameTimes.isEmpty || file.frameTimes.count == video.frames.count else {
            throw DecoderError.frameCount(file: file.path, pinned: file.frameTimes.count, counted: video.frames.count)
        }
        if let reading { try checkColor(video.taggedColor, in: reading.colorSpace, path: file.path) }
    }

    package func sound(
        of file: MediaFile,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        guard let sound = try soundTrack(at: file.path) else { throw DecoderError.noSound(file: file.path) }

        return try clock.measure(.decode) { try sound.sound(from: start, to: end, path: file.path) }
    }

    package func readings() -> MediaReadings {
        let media = tallies.withLock { $0 }
            .sorted { $0.value.order < $1.value.order }
            .map { key, tally in
                MediumReading(
                    path: key.path,
                    page: key.page,
                    conversion: key.conversion,
                    device: key.device,
                    pixelFormat: tally.pixelFormat,
                    framesRead: tally.framesRead,
                    framesDecoded: tally.framesDecoded,
                    reopened: tally.reopened
                )
            }

        let readAhead = aheadClock.seconds

        return MediaReadings(
            media: media,
            seconds: clock.seconds + readAhead,
            readAhead: readAhead,
            waiting: lookahead.waitingSeconds
        )
    }
}
