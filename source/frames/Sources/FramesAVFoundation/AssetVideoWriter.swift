//
//  AssetVideoWriter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import Frames

// Writes one video file with AVAssetWriter, straight to its path. Frame k is presented at k / fps. The sound, given
// whole, goes in after each frame up to that frame's end, so neither input waits on the other, and the rest at the
// end. Frames come at `size`, and the file's picture is the format's size when it has one, each frame scaled to it. A
// wait on the writer longer than `deadline` seconds cancels it. A writer that fails, or is let go before it finishes,
// cancels and removes its file.
final class AssetVideoWriter {
    // MARK: - Property
    private static let soundChunk = 48_000

    private let format: TargetFormat
    private let size: Size
    private let timing: FrameTiming
    private let deadline: Double
    private let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let audio: AVAssetWriterInput?
    private let sound: SoundBuffer?
    private let soundConverter: SoundConverter?
    private let frameConverter: FrameConverter

    private var frameCount = 0
    private var soundPosition = 0
    private var isClosed = false

    // MARK: - Initializer
    // An existing file at the format's path is replaced.
    init(
        format: TargetFormat,
        size: Size,
        fps: Double,
        sound: SoundBuffer?,
        deadline: Double
    ) throws {
        let url = URL(fileURLWithPath: format.path)
        if FileManager.default.fileExists(atPath: format.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                throw EncoderError.unwritable(file: format.path, reason: error.localizedDescription)
            }
        }

        let timing = FrameTiming(fps: fps)
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: format.fileType)
        } catch {
            throw EncoderError.unwritable(file: format.path, reason: error.localizedDescription)
        }
        writer.movieTimeScale = timing.timescale

        let picture = format.size ?? size
        let width = Int(picture.width)
        let height = Int(picture.height)
        let video = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: format.videoSettings(width: width, height: height)
        )
        video.mediaTimeScale = timing.timescale
        video.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: video,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: format.pixelFormat,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        writer.add(video)

        let audio = sound.map { AVAssetWriterInput(mediaType: .audio, outputSettings: format.audioSettings(for: $0)) }
        if let audio {
            audio.expectsMediaDataInRealTime = false
            writer.add(audio)
        }

        self.format = format
        self.size = size
        self.timing = timing
        self.deadline = deadline
        self.writer = writer
        self.video = video
        self.adaptor = adaptor
        self.audio = audio
        self.sound = sound
        self.soundConverter = try sound.map { try SoundConverter(sound: $0, path: format.path) }
        self.frameConverter = FrameConverter(keepsAlpha: format.keepsAlpha)

        guard writer.startWriting() else {
            abandon()
            throw failure("it cannot be started")
        }
        writer.startSession(atSourceTime: .zero)
    }

    deinit {
        if !isClosed { abandon() }
    }

    // MARK: - Public
    // MARK: - Private
    private func appendFrame(_ frame: Bitmap) throws {
        guard frame.width == Int(size.width), frame.height == Int(size.height) else {
            throw EncoderError.frameSize(
                file: format.path,
                index: frameCount,
                size: Size(width: Double(frame.width), height: Double(frame.height)),
                video: size
            )
        }

        var created: CVPixelBuffer?
        guard
            let pool = adaptor.pixelBufferPool,
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created) == kCVReturnSuccess,
            let buffer = created
        else {
            throw failure("no pixel buffer for frame \(frameCount)")
        }
        guard frameConverter.copy(frame, into: buffer) else { throw failure("frame \(frameCount) cannot be scaled") }

        try waitUntilReady(video, for: "frame \(frameCount)")
        guard adaptor.append(buffer, withPresentationTime: timing.time(ofFrame: frameCount)) else {
            throw failure("frame \(frameCount) cannot be appended")
        }
        frameCount += 1

        try appendSound(upTo: timing.time(ofFrame: frameCount))
    }

    private func finishWriting() throws {
        video.markAsFinished()
        if let sound {
            let end = CMTime(value: CMTimeValue(sound.frameCount), timescale: CMTimeScale(sound.sampleRate))
            try appendSound(upTo: end)
        }
        writer.endSession(atSourceTime: timing.time(ofFrame: frameCount))

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        guard semaphore.wait(timeout: .now() + deadline) == .success else {
            throw failure("it did not finish within \(deadline) seconds")
        }
        guard writer.status == .completed else { throw failure("it cannot be finished") }
    }

    // The sound up to `time`, in chunks of at most a second.
    private func appendSound(upTo time: CMTime) throws {
        guard let sound, let audio, soundPosition < sound.frameCount else { return }
        let end = min(Int((CMTimeGetSeconds(time) * sound.sampleRate).rounded()), sound.frameCount)

        while soundPosition < end {
            try waitUntilReady(audio, for: "sound from frame \(soundPosition)")
            try appendSoundChunk(to: min(soundPosition + Self.soundChunk, end))
        }
    }

    // The next second of sound, when the audio input takes it now. Gives whether it went in.
    private func appendSoundAhead() throws -> Bool {
        guard let sound, let audio, soundPosition < sound.frameCount, audio.isReadyForMoreMediaData else { return false }

        try appendSoundChunk(to: min(soundPosition + Self.soundChunk, sound.frameCount))

        return true
    }

    // The sound from the current position to `end`. The audio input is finished with the sound's last frame.
    private func appendSoundChunk(to end: Int) throws {
        guard let sound, let audio, let soundConverter else { return }

        let buffer = try soundConverter.sampleBuffer(from: soundPosition, to: end)
        guard audio.append(buffer) else { throw failure("sound from frame \(soundPosition) cannot be appended") }
        soundPosition = end
        if soundPosition == sound.frameCount {
            audio.markAsFinished()
        }
    }

    // The writer interleaves its tracks, and holds the video back until it has sound some way past the frames, so a
    // waiting video input takes the sound ahead of them.
    private func waitUntilReady(
        _ input: AVAssetWriterInput,
        for what: String
    ) throws {
        let start = Date()

        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw failure("\(what) cannot be appended") }
            guard Date().timeIntervalSince(start) < deadline else {
                throw failure("the writer did not take \(what) within \(deadline) seconds")
            }
            if input === video, try appendSoundAhead() { continue }

            Thread.sleep(forTimeInterval: 0.001)
        }
    }

    private func failure(_ reason: String) -> EncoderError {
        let detail = writer.error.map { ": \($0.localizedDescription)" } ?? ""

        return EncoderError.unwritable(file: format.path, reason: reason + detail)
    }

    // Cancels the writing, which returns once the writer has stopped, and removes what it wrote.
    private func abandon() {
        isClosed = true
        if writer.status == .writing {
            writer.cancelWriting()
        }
        try? FileManager.default.removeItem(atPath: format.path)
    }
}

extension AssetVideoWriter: VideoWriter {
    // MARK: - Lifecycle
    func append(_ frame: Bitmap) throws {
        do {
            try appendFrame(frame)
        } catch {
            abandon()
            throw error
        }
    }

    func finish() throws {
        do {
            try finishWriting()
        } catch {
            abandon()
            throw error
        }
        isClosed = true
    }
}
