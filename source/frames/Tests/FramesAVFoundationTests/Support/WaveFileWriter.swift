//
//  WaveFileWriter.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/23/26.
//

import Foundation

// Writes a WAVE file of 32-bit IEEE float samples, so each sample is read back as it is given.
struct WaveFileWriter {
    // MARK: - Property
    private let sampleRate: Int
    // Each channel's samples, all of one count.
    private let channels: [[Float]]

    // MARK: - Initializer
    init(
        sampleRate: Int = 48_000,
        channels: [[Float]]
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
    }

    // MARK: - Public
    func write(to path: String) throws {
        let channelCount = channels.count
        let frameCount = channels.first?.count ?? 0
        let dataSize = frameCount * channelCount * 4
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(4 + 26 + 12 + 8 + dataSize), to: &data)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(18), to: &data)
        append(UInt16(3), to: &data)
        append(UInt16(channelCount), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * channelCount * 4), to: &data)
        append(UInt16(channelCount * 4), to: &data)
        append(UInt16(32), to: &data)
        append(UInt16(0), to: &data)
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
