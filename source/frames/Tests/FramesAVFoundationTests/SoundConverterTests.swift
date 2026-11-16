//
//  SoundConverterTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("SoundConverter Tests")
struct SoundConverterTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("float samples become interleaved 24-bit integers clipped to full scale, from the frame asked for")
    func convertsWithClipping() throws {
        // Given
        let sound = SoundBuffer(sampleRate: 48_000, channels: 2, samples: [0.25, -0.25, 1.5, -1.5, 0.5, -1, 1, 0])
        let sut = try SoundConverter(sound: sound, path: "sound.mov")

        // When
        let buffer = try sut.sampleBuffer(from: 1, to: 4)

        // Then
        let description = try #require(CMSampleBufferGetFormatDescription(buffer).flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        })
        #expect(description.mBitsPerChannel == 24)
        #expect(description.mChannelsPerFrame == 2)
        #expect(description.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0)
        #expect(CMSampleBufferGetNumSamples(buffer) == 3)
        #expect(CMSampleBufferGetPresentationTimeStamp(buffer) == CMTime(value: 1, timescale: 48_000))
        #expect(try levels(of: buffer) == [8_388_607, -8_388_608, 4_194_304, -8_388_608, 8_388_607, 0])
    }

    // MARK: - Private
    // The little endian 24-bit samples of `buffer`, sign extended.
    private func levels(of buffer: CMSampleBuffer) throws -> [Int32] {
        let block = try #require(CMSampleBufferGetDataBuffer(buffer))
        let length = CMBlockBufferGetDataLength(block)
        var bytes = [UInt8](repeating: 0, count: length)
        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &bytes)

        return stride(from: 0, to: length, by: 3).map { start in
            let unsigned = Int32(bytes[start]) | Int32(bytes[start + 1]) << 8 | Int32(bytes[start + 2]) << 16

            return (unsigned << 8) >> 8
        }
    }
}
