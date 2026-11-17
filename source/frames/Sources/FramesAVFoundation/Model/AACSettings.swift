//
//  AACSettings.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation

// How AVFoundation writes AAC of one or two channels at `sampleRate`, at a constant `bitRate`: the rate the AAC
// encoder takes for that sample rate and channel count nearest the one asked, since a low sample rate caps it.
struct AACSettings: Equatable, Sendable {
    // MARK: - Property
    let sampleRate: Double
    let channels: Int
    let bitRate: Int

    var outputSettings: [String: Any] {
        var layout = AudioChannelLayout()
        layout.mChannelLayoutTag = channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo

        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVChannelLayoutKey: Data(bytes: &layout, count: MemoryLayout<AudioChannelLayout>.size),
            AVEncoderBitRateKey: bitRate,
            AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_Constant
        ]
    }

    // MARK: - Initializer
    init(
        sampleRate: Double,
        channels: Int,
        bitRate: Int
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitRate = Self.applicableBitRates(sampleRate: sampleRate, channels: channels)
            .min { abs($0 - bitRate) < abs($1 - bitRate) } ?? bitRate
    }

    // MARK: - Public
    // MARK: - Private
    // The bit rates an AAC converter from float PCM of this rate and channel count lists, each range's least.
    private static func applicableBitRates(
        sampleRate: Double,
        channels: Int
    ) -> [Int] {
        let count = UInt32(channels)
        var source = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4 * count,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4 * count,
            mChannelsPerFrame: count,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        var destination = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: count,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        var created: AudioConverterRef?
        guard AudioConverterNew(&source, &destination, &created) == noErr, let converter = created else { return [] }
        defer { AudioConverterDispose(converter) }

        var size: UInt32 = 0
        guard
            AudioConverterGetPropertyInfo(converter, kAudioConverterApplicableEncodeBitRates, &size, nil) == noErr
        else {
            return []
        }
        var ranges = [AudioValueRange](
            repeating: AudioValueRange(),
            count: Int(size) / MemoryLayout<AudioValueRange>.size
        )
        guard
            AudioConverterGetProperty(converter, kAudioConverterApplicableEncodeBitRates, &size, &ranges) == noErr
        else {
            return []
        }

        return ranges.map { Int($0.mMinimum) }.filter { $0 > 0 }
    }
}
