//
//  AssetSoundWriter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import Frames

// Writes one sound file of AAC with AVAssetWriter, straight to its path, from sound that already fits AAC, in chunks
// of at most a second. A wait on the writer longer than `deadline` seconds cancels it. A writer that fails cancels and
// removes its file.
final class AssetSoundWriter {
    // MARK: - Property
    private static let soundChunk = 48_000

    private let path: String
    private let settings: AACSettings
    private let deadline: Double

    // MARK: - Initializer
    init(
        path: String,
        settings: AACSettings,
        deadline: Double
    ) {
        self.path = path
        self.settings = settings
        self.deadline = deadline
    }

    // MARK: - Public
    // An existing file at the path is replaced.
    func write(_ sound: SoundBuffer) throws {
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                throw EncoderError.unwritable(file: path, reason: error.localizedDescription)
            }
        }

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: path), fileType: .m4a)
        } catch {
            throw EncoderError.unwritable(file: path, reason: error.localizedDescription)
        }
        guard writer.canApply(outputSettings: settings.outputSettings, forMediaType: .audio) else {
            throw EncoderError.unwritable(file: path, reason: "AAC at \(settings.sampleRate) Hz is not written")
        }
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: settings.outputSettings)
        audio.expectsMediaDataInRealTime = false
        writer.add(audio)

        do {
            try write(sound, with: writer, input: audio)
        } catch {
            if writer.status == .writing {
                writer.cancelWriting()
            }
            try? FileManager.default.removeItem(atPath: path)
            throw error
        }
    }

    // MARK: - Private
    private func write(
        _ sound: SoundBuffer,
        with writer: AVAssetWriter,
        input: AVAssetWriterInput
    ) throws {
        guard writer.startWriting() else { throw failure("it cannot be started", writer: writer) }
        writer.startSession(atSourceTime: .zero)

        let converter = try SoundConverter(sound: sound, path: path)
        var position = 0
        while position < sound.frameCount {
            let end = min(position + Self.soundChunk, sound.frameCount)
            try waitUntilReady(input, writer: writer, for: "sound from frame \(position)")
            guard input.append(try converter.sampleBuffer(from: position, to: end)) else {
                throw failure("sound from frame \(position) cannot be appended", writer: writer)
            }
            position = end
        }
        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        guard semaphore.wait(timeout: .now() + deadline) == .success else {
            throw failure("it did not finish within \(deadline) seconds", writer: writer)
        }
        guard writer.status == .completed else { throw failure("it cannot be finished", writer: writer) }
    }

    private func waitUntilReady(
        _ input: AVAssetWriterInput,
        writer: AVAssetWriter,
        for what: String
    ) throws {
        let start = Date()

        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw failure("\(what) cannot be appended", writer: writer) }
            guard Date().timeIntervalSince(start) < deadline else {
                throw failure("the writer did not take \(what) within \(deadline) seconds", writer: writer)
            }

            Thread.sleep(forTimeInterval: 0.001)
        }
    }

    private func failure(
        _ reason: String,
        writer: AVAssetWriter
    ) -> EncoderError {
        let detail = writer.error.map { ": \($0.localizedDescription)" } ?? ""

        return EncoderError.unwritable(file: path, reason: reason + detail)
    }
}
