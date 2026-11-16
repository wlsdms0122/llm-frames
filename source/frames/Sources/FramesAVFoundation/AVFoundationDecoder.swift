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
// pictures in the working space, and their sound. A still is read with ImageIO, its orientation applied, and a video
// with AVFoundation, its preferred transform applied. A video and a sound track are loaded once and kept.
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

    private func soundTrack(at path: String) throws -> SoundReader {
        if let sound = sounds.withLock({ $0[path] }) { return sound }
        guard let sound = try SoundReader(path: path) else { throw DecoderError.noSound(file: path) }
        sounds.withLock { $0[path] = sound }

        return sound
    }

    private func picture(of still: StillReader, path: String) throws -> Bitmap {
        converter.picture(from: try still.image(path: path), depth: still.depth)
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
            return ProbedMedia(kind: .image, size: still.displaySize)
        }
        if let video = try video(at: file) {
            return ProbedMedia(
                kind: .video,
                duration: video.duration,
                fps: video.fps,
                frames: video.frameTimes,
                size: video.displaySize,
                hasSound: video.hasSound
            )
        }

        // A file without a picture track is sound, or no media at all.
        let asset = AVURLAsset(url: URL(fileURLWithPath: file))
        let waiter = LoadWaiter(file: file)
        let sound = try waiter.tracks(of: asset, type: .audio)
        guard !sound.isEmpty else { throw DecoderError.unreadable(file: file) }
        let duration = try waiter.value(of: .duration, key: "duration", in: asset)

        return ProbedMedia(kind: .audio, duration: CMTimeGetSeconds(duration), hasSound: true)
    }

    // Every frame is the same size, or the directory is not a sequence.
    package func probedImageSequence(at directory: String) throws -> ProbedImageSequence? {
        guard FileManager.default.fileExists(atPath: directory) else { return nil }
        let files = try frameFiles(in: directory)
        guard let first = files.first else { throw DecoderError.emptySequence(directory: directory) }
        guard let size = try StillReader(path: first)?.displaySize else { throw DecoderError.unreadable(file: first) }

        for file in files.dropFirst() {
            guard let frameSize = try StillReader(path: file)?.displaySize else {
                throw DecoderError.unreadable(file: file)
            }
            guard frameSize == size else { throw DecoderError.unequalFrame(file: file, size: frameSize, first: size) }
        }

        return ProbedImageSequence(files: files, size: size)
    }
}

extension AVFoundationDecoder: MediaDecoder {
    // MARK: - Lifecycle
    package func picture(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> Bitmap {
        if !file.frameFiles.isEmpty {
            guard file.frameFiles.indices.contains(index) else {
                throw DecoderError.noFrame(file: file.path, index: index, count: file.frameFiles.count)
            }

            let path = file.frameFiles[index]
            guard let still = try StillReader(path: path) else { throw DecoderError.unreadable(file: path) }

            return try picture(of: still, path: path)
        }
        if let still = try StillReader(path: file.path) {
            guard index == 0 else { throw DecoderError.noFrame(file: file.path, index: index, count: 1) }

            return try picture(of: still, path: file.path)
        }

        guard let video = try video(at: file.path) else { throw DecoderError.unreadable(file: file.path) }
        let count = video.frames.count
        guard file.frameTimes.isEmpty || file.frameTimes.count == count else {
            throw DecoderError.frameCount(file: file.path, pinned: file.frameTimes.count, counted: count)
        }
        guard video.frames.indices.contains(index) else {
            throw DecoderError.noFrame(file: file.path, index: index, count: count)
        }

        return converter.picture(
            from: try video.image(atFrame: index, path: file.path),
            depth: video.depth
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
        of file: String,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        try soundTrack(at: file).sound(from: start, to: end, path: file)
    }
}
