//
//  SoundReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import Foundation
import Frames

// A media file's first sound track, loaded once: its sample rate and the speakers its channels feed. It is read on the
// file's presentation timeline, as its pictures are.
struct SoundReader: Sendable {
    // MARK: - Property
    let sampleRate: Double
    let layout: ChannelLayout

    private let asset: AVURLAsset
    // A track is only read once it is loaded, which AVFoundation allows from any thread.
    nonisolated(unsafe) private let track: AVAssetTrack
    private let outputSettings: [String: any Sendable]

    // MARK: - Initializer
    // Nil for a file without a sound track.
    init?(path: String) throws {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let waiter = LoadWaiter(file: path)
        guard let track = try waiter.tracks(of: asset, type: .audio).first else { return nil }
        let formats = try waiter.value(of: .formatDescriptions, key: "formatDescriptions", in: track)
        guard
            let format = formats.first,
            let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee
        else {
            throw DecoderError.unreadable(file: path)
        }
        let channels = Int(description.mChannelsPerFrame)
        var layoutSize = 0
        let audioLayout = CMAudioFormatDescriptionGetChannelLayout(format, sizeOut: &layoutSize)

        // Decoded samples keep the order of the track's own layout, which names the speakers.
        var settings: [String: any Sendable] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        if let audioLayout {
            settings[AVChannelLayoutKey] = Data(bytes: audioLayout, count: layoutSize)
        }

        self.asset = asset
        self.track = track
        self.sampleRate = description.mSampleRate
        self.layout = audioLayout.map { ChannelLayout(audioChannelLayout: $0, channels: channels) }
            ?? ChannelLayout(channels: channels)
        self.outputSettings = settings
    }

    // MARK: - Public
    // The samples over media time [start, end), each placed by its presentation time so a gap in the track stays
    // silent. A range past the end of the track gives the frames there are.
    func sound(
        from start: Double,
        to end: Double,
        path: String
    ) throws -> SoundBuffer {
        let channels = layout.labels.count
        let first = Int((start * sampleRate).rounded())
        let count = Int((end * sampleRate).rounded()) - first
        guard count > 0 else {
            return SoundBuffer(sampleRate: sampleRate, channels: channels, samples: [], layout: layout)
        }

        let timescale = CMTimeScale(sampleRate.rounded())
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        // Media time before 0 holds no sound, and stays silent.
        let readFirst = max(first, 0)
        reader.timeRange = CMTimeRange(
            start: CMTime(value: CMTimeValue(readFirst), timescale: timescale),
            duration: CMTime(value: CMTimeValue(first + count - readFirst), timescale: timescale)
        )
        guard reader.startReading() else { throw DecoderError.unreadable(file: path) }
        defer { reader.cancelReading() }

        var samples = [Float](repeating: 0, count: count * channels)
        var reached = 0
        while let buffer = output.copyNextSampleBuffer() {
            let frames = CMSampleBufferGetNumSamples(buffer)
            guard frames > 0, let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let offset = Int((CMSampleBufferGetPresentationTimeStamp(buffer).seconds * sampleRate).rounded()) - first
            guard offset < count else { break }
            let kept = max(-offset, 0)..<min(frames, count - offset)
            guard !kept.isEmpty else { continue }

            var decoded = [Float](repeating: 0, count: frames * channels)
            let status = decoded.withUnsafeMutableBytes { bytes in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: bytes.count, destination: bytes.baseAddress!)
            }
            guard status == kCMBlockBufferNoErr else { throw DecoderError.unreadable(file: path) }
            samples.replaceSubrange(
                (offset + kept.lowerBound) * channels..<(offset + kept.upperBound) * channels,
                with: decoded[kept.lowerBound * channels..<kept.upperBound * channels]
            )
            reached = max(reached, offset + kept.upperBound)
        }
        guard reader.status != .failed else { throw DecoderError.unreadable(file: path) }

        return SoundBuffer(
            sampleRate: sampleRate,
            channels: channels,
            samples: Array(samples.prefix(reached * channels)),
            layout: layout
        )
    }

    // MARK: - Private
}
