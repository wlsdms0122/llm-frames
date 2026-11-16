//
//  SoundConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import Frames

// Turns a run of a sound's frames into a sample buffer of interleaved 24-bit signed integer linear PCM, each sample
// clipped to full scale: what a master stores as it is, and what an AAC encoder reads.
struct SoundConverter {
    // MARK: - Property
    private static let bytesPerSample = 3
    private static let fullScale = 8_388_608.0

    private let sound: SoundBuffer
    private let format: CMAudioFormatDescription
    private let path: String

    // MARK: - Initializer
    init(
        sound: SoundBuffer,
        path: String
    ) throws {
        var description = AudioStreamBasicDescription(
            mSampleRate: sound.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(Self.bytesPerSample * sound.channels),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(Self.bytesPerSample * sound.channels),
            mChannelsPerFrame: UInt32(sound.channels),
            mBitsPerChannel: UInt32(Self.bytesPerSample * 8),
            mReserved: 0
        )
        var format: CMAudioFormatDescription?
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
            let format
        else {
            throw EncoderError.unwritable(file: path, reason: "its sound format cannot be described")
        }

        self.sound = sound
        self.format = format
        self.path = path
    }

    // MARK: - Public
    // Frames `start` to `end` of the sound, presented at `start` / sample rate.
    func sampleBuffer(
        from start: Int,
        to end: Int
    ) throws -> CMSampleBuffer {
        let count = end - start
        let length = count * sound.channels * Self.bytesPerSample
        var bytes = [UInt8](repeating: 0, count: length)
        for index in 0..<count * sound.channels {
            let sample = Double(sound.samples[start * sound.channels + index])
            let level = Int32(max(-Self.fullScale, min(Self.fullScale - 1, (sample * Self.fullScale).rounded())))
            for byte in 0..<Self.bytesPerSample {
                bytes[index * Self.bytesPerSample + byte] = UInt8(truncatingIfNeeded: level >> (byte * 8))
            }
        }

        var block: CMBlockBuffer?
        var sample: CMSampleBuffer?
        guard
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
            let block,
            CMBlockBufferReplaceDataBytes(
                with: &bytes,
                blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: length
            ) == noErr,
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: nil,
                dataBuffer: block,
                formatDescription: format,
                sampleCount: count,
                presentationTimeStamp: CMTime(value: CMTimeValue(start), timescale: CMTimeScale(sound.sampleRate)),
                packetDescriptions: nil,
                sampleBufferOut: &sample
            ) == noErr,
            let sample
        else {
            throw EncoderError.unwritable(file: path, reason: "its sound from frame \(start) cannot be buffered")
        }

        return sample
    }

    // MARK: - Private
}
