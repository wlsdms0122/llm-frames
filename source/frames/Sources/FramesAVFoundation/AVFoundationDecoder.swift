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
// video and a sound track are loaded once and kept.
package final class AVFoundationDecoder: Sendable {
    // MARK: - Property
    private let converter = PictureConverter()
    private let videos = OSAllocatedUnfairLock<[String: VideoReader]>(initialState: [:])
    private let sounds = OSAllocatedUnfairLock<[String: SoundReader]>(initialState: [:])

    // MARK: - Initializer
    package init() {}

    // MARK: - Public
    // MARK: - Private
    private func video(at path: String) throws -> VideoReader? {
        if let video = videos.withLock({ $0[path] }) { return video }
        guard let video = try VideoReader(path: path) else { return nil }
        videos.withLock { $0[path] = video }

        return video
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

    private func picture(
        of still: StillReader,
        path: String,
        reading: PictureReading
    ) throws -> Bitmap {
        let tagged = reading.colorSpace == nil ? try still.taggedColor(path: path) : nil

        return try picture(from: try still.image(path: path), tagged: tagged, path: path, reading: reading)
    }

    // `tagged` is the file's colour, which a reading that names a colour space does not need.
    private func picture(
        from image: CIImage,
        tagged: TaggedColor?,
        path: String,
        reading: PictureReading
    ) throws -> Bitmap {
        let color: MediaColor
        if let colorSpace = reading.colorSpace {
            color = .space(colorSpace)
        } else {
            do {
                color = try tagged?.color.get() ?? .space(.srgb)
            } catch {
                throw DecoderError.unconvertibleColor(file: path, reason: error.reason)
            }
        }
        let conversion = MediaColorConversion(color)

        switch reading {
        case let .working(_, targetPeak):
            let toneMapping = targetPeak.flatMap {
                conversion.toneMapping(masteringDisplayPeak: tagged?.masteringDisplayPeak, targetPeak: $0)
            }
            return converter.picture(from: image, conversion: conversion, toneMapping: toneMapping)

        case .analysis:
            let toneMapping = conversion.toneMapping(
                masteringDisplayPeak: tagged?.masteringDisplayPeak,
                targetPeak: ColorSpace.srgb.peakLuminance
            )
            return converter.analysisPicture(from: image, conversion: conversion, toneMapping: toneMapping)
        }
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
}

extension AVFoundationDecoder: MediaDecoder {
    // MARK: - Lifecycle
    package func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Bitmap {
        if !file.frameFiles.isEmpty {
            guard file.frameFiles.indices.contains(index) else {
                throw DecoderError.noFrame(file: file.path, index: index, count: file.frameFiles.count)
            }

            let path = file.frameFiles[index]
            guard let still = try StillReader(path: path) else { throw DecoderError.unreadable(file: path) }

            return try picture(of: still, path: path, reading: reading)
        }
        if let still = try StillReader(path: file.path) {
            guard index == 0 else { throw DecoderError.noFrame(file: file.path, index: index, count: 1) }

            return try picture(of: still, path: file.path, reading: reading)
        }

        guard let video = try video(at: file.path) else { throw DecoderError.unreadable(file: file.path) }
        let count = video.frames.count
        guard file.frameTimes.isEmpty || file.frameTimes.count == count else {
            throw DecoderError.frameCount(file: file.path, pinned: file.frameTimes.count, counted: count)
        }
        guard video.frames.indices.contains(index) else {
            throw DecoderError.noFrame(file: file.path, index: index, count: count)
        }

        if reading.colorSpace == nil, case let .failure(refusal) = video.taggedColor.color {
            throw DecoderError.unconvertibleColor(file: file.path, reason: refusal.reason)
        }

        return try picture(
            from: try video.image(atFrame: index, path: file.path),
            tagged: video.taggedColor,
            path: file.path,
            reading: reading
        )
    }

    package func check(_ file: MediaFile) throws {
        if !file.frameFiles.isEmpty {
            for path in file.frameFiles {
                guard try StillReader(path: path) != nil else { throw DecoderError.unreadable(file: path) }
            }

            return
        }
        if try StillReader(path: file.path) != nil { return }

        // A file without a picture track is sound, or no media at all.
        guard let video = try video(at: file.path) else {
            guard (try? soundTrack(at: file.path)) != nil else { throw DecoderError.unreadable(file: file.path) }

            return
        }
        guard file.frameTimes.isEmpty || file.frameTimes.count == video.frames.count else {
            throw DecoderError.frameCount(file: file.path, pinned: file.frameTimes.count, counted: video.frames.count)
        }
    }

    package func sound(
        of file: MediaFile,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        guard let sound = try soundTrack(at: file.path) else { throw DecoderError.noSound(file: file.path) }

        return try sound.sound(from: start, to: end, path: file.path)
    }
}
