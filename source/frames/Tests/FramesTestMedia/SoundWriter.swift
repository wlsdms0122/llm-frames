//
//  SoundWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import Foundation

// Writes a file that holds only sound: `signal`, a 440 Hz tone unless told otherwise, from 0 to `end` seconds at
// `sampleRate`, each channel at its own level of `levels` (full scale 1), in the layout of that many channels (mono,
// stereo, 3.0, 4.0, 5.0, 5.1, 6.1 or 7.1 in SMPTE order). A `.wav` file holds 16 bit linear PCM and any other AAC. A
// movie writer takes its tone from here too, a 440 Hz mono one at 48 kHz.
package struct SoundWriter {
    // MARK: - Property
    static var outputSettings: [String: Any] {
        SoundWriter(end: 0).settings(linear: false)
    }

    private let end: Double
    private let sampleRate: Int
    private let signal: SoundSignal
    private let levels: [Double]

    private var layoutTag: AudioChannelLayoutTag {
        switch levels.count {
        case 1:
            kAudioChannelLayoutTag_Mono

        case 2:
            kAudioChannelLayoutTag_Stereo

        case 3:
            kAudioChannelLayoutTag_MPEG_3_0_A

        case 4:
            kAudioChannelLayoutTag_MPEG_4_0_A

        case 5:
            kAudioChannelLayoutTag_MPEG_5_0_A

        case 6:
            kAudioChannelLayoutTag_MPEG_5_1_A

        case 7:
            kAudioChannelLayoutTag_MPEG_6_1_A

        default:
            kAudioChannelLayoutTag_MPEG_7_1_C
        }
    }

    private var layout: AudioChannelLayout {
        layout(tag: layoutTag)
    }

    // MARK: - Initializer
    package init(
        end: Double,
        sampleRate: Int = 48_000,
        signal: SoundSignal = .tone(frequency: 440),
        levels: [Double] = [8_000.0 / 32_768]
    ) {
        self.end = end
        self.sampleRate = sampleRate
        self.signal = signal
        self.levels = levels
    }

    // MARK: - Public
    package func write(to path: String) async throws {
        let url = URL(fileURLWithPath: path)
        let linear = url.pathExtension == "wav"
        let writer = try AVAssetWriter(outputURL: url, fileType: linear ? .wav : .m4a)
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: settings(linear: linear))
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

    // The sample of `channel` at frame `index`, as written before 16 bit rounding.
    package func sample(
        channel: Int,
        at index: Int
    ) -> Double {
        signal.value(channel: channel, at: index, sampleRate: sampleRate) * levels[channel]
    }

    // 16 bit interleaved samples of the tone from `start` to `end` media seconds.
    func tone(
        from start: Double,
        to end: Double,
        path: String
    ) throws -> CMSampleBuffer {
        let channels = levels.count
        let first = Int((start * Double(sampleRate)).rounded())
        let count = max(Int((end * Double(sampleRate)).rounded()) - first, 1)
        var samples = (0..<count * channels).map { index in
            let value = sample(channel: index % channels, at: first + index / channels) * 32_768

            return Int16(min(max(value.rounded(.towardZero), -32_768), 32_767))
        }
        var description = AudioStreamBasicDescription(
            mSampleRate: Double(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(2 * channels),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(2 * channels),
            mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var layout = layout
        var format: CMAudioFormatDescription?
        var block: CMBlockBuffer?
        var sample: CMSampleBuffer?
        let length = count * channels * 2
        guard
            CMAudioFormatDescriptionCreate(
                allocator: nil,
                asbd: &description,
                layoutSize: MemoryLayout<AudioChannelLayout>.size,
                layout: &layout,
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
                presentationTimeStamp: CMTime(value: CMTimeValue(first), timescale: CMTimeScale(sampleRate)),
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
    // AAC stores 5.1 in its own channel order, which the writer maps the written layout onto.
    private func settings(linear: Bool) -> [String: Any] {
        let stored = !linear && levels.count == 6 ? layout(tag: kAudioChannelLayoutTag_AAC_5_1) : layout
        let layout = withUnsafeBytes(of: stored) { Data($0) }
        guard linear else {
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: levels.count,
                AVChannelLayoutKey: layout,
                AVEncoderBitRateKey: 64_000 * max(levels.count, 2)
            ]
        }

        return [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: levels.count,
            AVChannelLayoutKey: layout,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }

    private func layout(tag: AudioChannelLayoutTag) -> AudioChannelLayout {
        AudioChannelLayout(
            mChannelLayoutTag: tag,
            mChannelBitmap: [],
            mNumberChannelDescriptions: 0,
            mChannelDescriptions: AudioChannelDescription()
        )
    }
}
