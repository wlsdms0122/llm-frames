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
import ImageIO
import os
import UniformTypeIdentifiers

// The `avfoundation` decoder: probes media files and image sequence directories, and reads their frames by index as
// pictures in the working space. A still is read with ImageIO, its orientation applied, and a video with AVFoundation,
// its preferred transform applied. A video is loaded once and kept.
package final class AVFoundationDecoder: Sendable {
    // MARK: - Property
    private let converter = PictureConverter()
    private let videos = OSAllocatedUnfairLock<[String: VideoReader]>(initialState: [:])

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

    private func isStill(_ path: String) -> Bool {
        guard
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            let type = CGImageSourceGetType(source).flatMap({ UTType($0 as String) })
        else {
            return false
        }

        return type.conforms(to: .image) && CGImageSourceGetCount(source) > 0
    }

    // A still's size as it is displayed: an orientation that turns it a quarter swaps width and height.
    private func stillSize(of path: String) -> Size? {
        guard
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Double,
            let height = properties[kCGImagePropertyPixelHeight] as? Double
        else {
            return nil
        }
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1

        return orientation >= 5 ? Size(width: height, height: width) : Size(width: width, height: height)
    }

    private func stillBitsPerComponent(of path: String) -> Int {
        guard
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return 8
        }

        return properties[kCGImagePropertyDepth] as? Int ?? 8
    }

    private func still(at path: String) throws -> DecodedPicture {
        guard
            let image = CIImage(contentsOf: URL(fileURLWithPath: path), options: [.applyOrientationProperty: true])
        else {
            throw DecoderError.unreadable(file: path)
        }

        return converter.picture(from: image, bitsPerComponent: stillBitsPerComponent(of: path))
    }

    // The PNG files in a directory in natural order, so `frame2` comes before `frame10`.
    private func frameFiles(in directory: String) -> [String]? {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return nil }

        return names
            .filter { ($0 as NSString).pathExtension.lowercased() == "png" }
            .sorted { $0.compare($1, options: [.numeric]) == .orderedAscending }
            .map { (directory as NSString).appendingPathComponent($0) }
    }
}

extension AVFoundationDecoder: MediaFactProvider {
    // MARK: - Lifecycle
    package func probedMedia(of file: String) -> ProbedMedia? {
        if isStill(file) {
            return stillSize(of: file).map { ProbedMedia(kind: .image, size: $0) }
        }
        if let video = try? video(at: file) {
            return ProbedMedia(
                kind: .video,
                duration: video.duration,
                fps: video.fps,
                frames: video.frameTimes,
                size: video.displaySize,
                hasSound: video.hasSound
            )
        }

        let asset = AVURLAsset(url: URL(fileURLWithPath: file))
        guard
            let (hasSound, duration) = try? LoadWaiter().value(of: {
                (!(try await asset.loadTracks(withMediaType: .audio)).isEmpty, try await asset.load(.duration))
            }),
            hasSound
        else {
            return nil
        }

        return ProbedMedia(kind: .audio, duration: CMTimeGetSeconds(duration), hasSound: true)
    }

    // Every frame is the same size, or the directory is not a sequence.
    package func probedImageSequence(at directory: String) -> ProbedImageSequence? {
        guard
            let files = frameFiles(in: directory),
            let size = files.first.flatMap(stillSize(of:)),
            files.allSatisfy({ stillSize(of: $0) == size })
        else {
            return nil
        }

        return ProbedImageSequence(files: files, size: size)
    }
}

extension AVFoundationDecoder: MediaDecoder {
    // MARK: - Lifecycle
    package func picture(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> DecodedPicture {
        if !file.frameFiles.isEmpty {
            guard file.frameFiles.indices.contains(index) else {
                throw DecoderError.noFrame(file: file.path, index: index, count: file.frameFiles.count)
            }

            return try still(at: file.frameFiles[index])
        }
        if isStill(file.path) {
            guard index == 0 else { throw DecoderError.noFrame(file: file.path, index: index, count: 1) }

            return try still(at: file.path)
        }

        guard let video = try video(at: file.path) else { throw DecoderError.unreadable(file: file.path) }
        let count = video.presentationTimes.count
        guard file.frameTimes.isEmpty || file.frameTimes.count == count else {
            throw DecoderError.frameCount(file: file.path, pinned: file.frameTimes.count, counted: count)
        }
        guard video.presentationTimes.indices.contains(index) else {
            throw DecoderError.noFrame(file: file.path, index: index, count: count)
        }

        return converter.picture(
            from: try video.image(atFrame: index, path: file.path),
            bitsPerComponent: video.bitsPerComponent
        )
    }
}
