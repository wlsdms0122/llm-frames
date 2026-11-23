//
//  MultitrackSoundWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/23/26.
//

import AVFoundation
import Foundation

// Writes a `.mov` that holds only sound, one sound track for each of `tracks` in their order, each the 16 bit linear
// PCM sound its writer gives from 0 to `end` seconds.
package struct MultitrackSoundWriter {
    // MARK: - Property
    private let end: Double
    private let tracks: [SoundWriter]

    // MARK: - Initializer
    package init(
        end: Double,
        tracks: [SoundWriter]
    ) {
        self.end = end
        self.tracks = tracks
    }

    // MARK: - Public
    package func write(to path: String) async throws {
        let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: path), fileType: .mov)
        let inputs = tracks.map { track in
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: track.settings(linear: true))
            input.expectsMediaDataInRealTime = false
            writer.add(input)

            return input
        }
        guard writer.startWriting() else { throw writer.error ?? TestMediaError.unwritable(path) }
        writer.startSession(atSourceTime: .zero)

        for (track, input) in zip(tracks, inputs) {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            guard input.append(try track.tone(from: 0, to: end, path: path)) else {
                throw writer.error ?? TestMediaError.unwritable(path)
            }
            input.markAsFinished()
        }
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? TestMediaError.unwritable(path) }
    }

    // MARK: - Private
}
