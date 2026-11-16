//
//  StereoDownmixerTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("StereoDownmixer Tests")
struct StereoDownmixerTests {
    // MARK: - Property
    // Two labels and the left and right outputs of a frame holding 0.5 on the first channel and 0.25 on the second.
    private static let twoChannelMixes: [([ChannelLabel], [Float])] = [
        ([.left, .right], [0.5, 0.25]),
        ([.center, .lowFrequencyEffects], [0.7071 * 0.5, 0.7071 * 0.5]),
        ([.right, .left], [0.25, 0.5])
    ]

    private let tolerance: Float = 1e-6

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "two channels are mixed by their labels, so a centre reaches both sides at 0.7071 and LFE is dropped",
        arguments: twoChannelMixes
    )
    func mixesTwoChannelsByLabel(
        labels: [ChannelLabel],
        stereo: [Float]
    ) throws {
        // Given
        let sound = SoundBuffer(
            sampleRate: 48_000,
            channels: 2,
            samples: [0.5, 0.25, 0.5, 0.25],
            layout: ChannelLayout(labels: labels)
        )
        let sut = try #require(StereoDownmixer(layout: sound.layout))

        // When
        let buffer = try sut.stereo(from: sound, path: "/abs/two.wav")

        // Then
        let channels = try #require(buffer.floatChannelData)
        #expect(buffer.frameLength == 2)
        for frame in 0..<2 {
            #expect(abs(channels[0][frame] - stereo[0]) < tolerance)
            #expect(abs(channels[1][frame] - stereo[1]) < tolerance)
        }
    }

    @Test("one channel plays at its own level on both sides, whatever its label")
    func playsOneChannelOnBoth() throws {
        // Given
        let sound = SoundBuffer(
            sampleRate: 48_000,
            channels: 1,
            samples: [0.5],
            layout: ChannelLayout(labels: [.center])
        )
        let sut = try #require(StereoDownmixer(layout: sound.layout))

        // When
        let buffer = try sut.stereo(from: sound, path: "/abs/one.wav")

        // Then
        let channels = try #require(buffer.floatChannelData)
        #expect(channels[0][0] == 0.5 && channels[1][0] == 0.5)
    }

    @Test("two discrete channels name no speaker, so they are refused")
    func refusesDiscreteChannels() {
        // Given
        let layout = ChannelLayout(labels: [.discrete, .discrete])

        // When
        let sut = StereoDownmixer(layout: layout)

        // Then
        #expect(sut == nil)
    }

    // MARK: - Private
}
