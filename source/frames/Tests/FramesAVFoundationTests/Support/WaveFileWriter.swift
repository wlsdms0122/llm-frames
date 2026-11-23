//
//  WaveFileWriter.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/23/26.
//

import Foundation

// Writes a WAVE file of 32-bit IEEE float samples, so each sample is read back as it is given. With a channel mask it
// is WAVE_FORMAT_EXTENSIBLE, whose mask names the speaker of each channel in the order of its bits (0 names none), and
// without one it is a plain WAVE_FORMAT_IEEE_FLOAT file, which names no speaker.
struct WaveFileWriter {
    // MARK: - Property
    // The GUID of KSDATAFORMAT_SUBTYPE_IEEE_FLOAT after its first four bytes, which are the format tag 3.
    private static let floatSubformatTail: [UInt8] = [
        0x00, 0x00, 0x10, 0x00, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71
    ]

    private let sampleRate: Int
    // Each channel's samples, all of one count.
    private let channels: [[Float]]
    private let channelMask: UInt32?

    // MARK: - Initializer
    init(
        sampleRate: Int = 48_000,
        channels: [[Float]],
        channelMask: UInt32? = nil
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.channelMask = channelMask
    }

    // MARK: - Public
    func write(to path: String) throws {
        let channelCount = channels.count
        let frameCount = channels.first?.count ?? 0
        let dataSize = frameCount * channelCount * 4
        let formatSize = channelMask == nil ? 18 : 40
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(4 + 8 + formatSize + 12 + 8 + dataSize), to: &data)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(formatSize), to: &data)
        append(UInt16(channelMask == nil ? 3 : 0xFFFE), to: &data)
        append(UInt16(channelCount), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * channelCount * 4), to: &data)
        append(UInt16(channelCount * 4), to: &data)
        append(UInt16(32), to: &data)
        if let channelMask {
            append(UInt16(22), to: &data)
            append(UInt16(32), to: &data)
            append(channelMask, to: &data)
            append(UInt32(3), to: &data)
            data.append(contentsOf: Self.floatSubformatTail)
        } else {
            append(UInt16(0), to: &data)
        }
        data.append(contentsOf: Array("fact".utf8))
        append(UInt32(4), to: &data)
        append(UInt32(frameCount), to: &data)
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize), to: &data)
        for frame in 0..<frameCount {
            for channel in channels {
                append(channel[frame].bitPattern, to: &data)
            }
        }
        try data.write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Private
    private func append<Value: FixedWidthInteger>(
        _ value: Value,
        to data: inout Data
    ) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
