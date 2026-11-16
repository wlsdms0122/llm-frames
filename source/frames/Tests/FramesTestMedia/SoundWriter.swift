//
//  SoundWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import Foundation

// Writes an AAC file that holds only sound: a 440 Hz mono tone from 0 to `end` seconds. A video writer takes its tone
// from here too.
package struct SoundWriter {
    // MARK: - Property
    static let sampleRate = 48_000
    static var outputSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ]
    }

    private let end: Double

    // MARK: - Initializer
    package init(end: Double) {
        self.end = end
    }

    // MARK: - Public
    package func write(to path: String) async throws {
        let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: path), fileType: .m4a)
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: Self.outputSettings)
        audio.expectsMediaDataInRealTime = false
        writer.add(audio)
        guard writer.startWriting() else { throw writer.error ?? TestMediaError.unwritable(path) }
        writer.startSession(atSourceTime: .zero)

        while !audio.isReadyForMoreMediaData {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        guard audio.append(try tone(from: 0, to: end, path: path)) else {
            throw writer.error ?? TestMediaError.unwritable(path)
        }
        audio.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? TestMediaError.unwritable(path) }
    }

    // 16 bit mono samples of the tone from `start` to `end` media seconds.
    func tone(
        from start: Double,
        to end: Double,
        path: String
    ) throws -> CMSampleBuffer {
        let first = Int((start * Double(Self.sampleRate)).rounded())
        let count = max(Int((end * Double(Self.sampleRate)).rounded()) - first, 1)
        var samples = (0..<count).map { offset in
            Int16(sin(2 * Double.pi * 440 * Double(first + offset) / Double(Self.sampleRate)) * 8_000)
        }
        var description = AudioStreamBasicDescription(
            mSampleRate: Double(Self.sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var format: CMAudioFormatDescription?
        var block: CMBlockBuffer?
        var sample: CMSampleBuffer?
        let length = count * 2
        guard
            CMAudioFormatDescriptionCreate(
                allocator: nil,
                asbd: &description,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: nil,
                formatDescriptionOut: &format
            ) == noErr,
            CMBlockBufferCreateWithMemoryBlock(
                allocator: nil,
                memoryBlock: nil,
                blockLength: length,
                blockAllocator: nil,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: length,
                flags: 0,
                blockBufferOut: &block
            ) == noErr,
            let format,
            let block,
            CMBlockBufferReplaceDataBytes(
                with: &samples,
                blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: length
            ) == noErr,
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: nil,
                dataBuffer: block,
                formatDescription: format,
                sampleCount: count,
                presentationTimeStamp: CMTime(value: CMTimeValue(first), timescale: CMTimeScale(Self.sampleRate)),
                packetDescriptions: nil,
                sampleBufferOut: &sample
            ) == noErr,
            let sample
        else {
            throw TestMediaError.unwritable(path)
        }

        return sample
    }

    // MARK: - Private
}
