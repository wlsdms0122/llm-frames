//
//  TargetFormat.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import VideoToolbox
import Frames

// How AVFoundation writes an encode target, tagged with its output's colour space. H.264 and HEVC take 8-bit BGRA,
// which their hardware encoders read natively, since 16-bit RGBA handed to them can fault the hardware encoder.
struct TargetFormat: Equatable, Sendable {
    // MARK: - Property
    private static let sampleRate = 48_000
    private static let channels = 2
    private static let deliveryBitRate = 256_000

    let target: EncodeTarget
    let path: String
    let fileType: AVFileType
    let codec: AVVideoCodecType
    let codecType: CMVideoCodecType
    let codecName: String
    let keepsAlpha: Bool
    let pixelFormat: OSType
    // The file's picture, when it is not the frames' own.
    let size: Size?

    var colorProperties: [String: String] {
        target.output.space.videoColorProperties
    }

    // A master's or a delivery's sound settings, the same for any sound, so the encoder's check tries them before a
    // file is written. A compressed video's depend on its sound, which is checked as a sound target, so it has none.
    var fixedAudioSettings: [String: Any]? {
        switch target {
        case .master:
            var channelLayout = AudioChannelLayout()
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo

            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: Self.sampleRate,
                AVNumberOfChannelsKey: Self.channels,
                AVChannelLayoutKey: Data(bytes: &channelLayout, count: MemoryLayout<AudioChannelLayout>.size),
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]

        case .delivery:
            return AACSettings(
                sampleRate: Double(Self.sampleRate),
                channels: Self.channels,
                bitRate: Self.deliveryBitRate
            ).outputSettings

        case .compressed:
            return nil
        }
    }

    // MARK: - Initializer
    init(target: EncodeTarget) {
        self.target = target

        switch target {
        case let .master(path, alpha, _):
            self.path = path
            fileType = .mov
            codec = alpha ? .proRes4444 : .proRes422HQ
            codecType = alpha ? kCMVideoCodecType_AppleProRes4444 : kCMVideoCodecType_AppleProRes422HQ
            codecName = alpha ? "ProRes 4444" : "ProRes 422 HQ"
            keepsAlpha = alpha
            pixelFormat = kCVPixelFormatType_64RGBALE
            size = nil

        case let .delivery(path, _):
            self.path = path
            fileType = .mp4
            codec = .h264
            codecType = kCMVideoCodecType_H264
            codecName = "H.264"
            keepsAlpha = false
            pixelFormat = kCVPixelFormatType_32BGRA
            size = nil

        case let .compressed(path, videoCodec, _, size, _):
            self.path = path
            fileType = Self.fileType(of: path)
            codec = videoCodec == .hevc ? .hevc : .h264
            codecType = videoCodec == .hevc ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
            codecName = videoCodec.name
            keepsAlpha = false
            pixelFormat = kCVPixelFormatType_32BGRA
            self.size = size
        }
    }

    // MARK: - Public
    // The settings for `sound`, which a compressed target has fitted to AAC already.
    func audioSettings(for sound: SoundBuffer) -> [String: Any] {
        switch target {
        case let .compressed(_, _, quality, _, _):
            AACSettings(
                sampleRate: sound.sampleRate,
                channels: sound.channels,
                bitRate: quality.soundBitRate * sound.channels
            ).outputSettings

        case .master, .delivery:
            fixedAudioSettings ?? [:]
        }
    }

    func videoSettings(
        width: Int,
        height: Int
    ) -> [String: Any] {
        let compression: [String: Any] = switch target {
        case .master(_, alpha: true, _):
            [kVTCompressionPropertyKey_AlphaChannelMode as String: kVTAlphaChannelMode_PremultipliedAlpha as String]

        case .master:
            [:]

        case .delivery:
            [AVVideoQualityKey: 1.0]

        case let .compressed(_, _, quality, _, _):
            [AVVideoQualityKey: videoQuality(of: quality)]
        }

        return [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: colorProperties,
            AVVideoCompressionPropertiesKey: compression
        ]
    }

    // MARK: - Private
    private static func fileType(of path: String) -> AVFileType {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "mov":
            .mov

        case "m4v":
            .m4v

        default:
            .mp4
        }
    }

    // Measured on screen recordings and camera like clips: at 0.7, 0.5 and 0.3 H.264 and HEVC give about 90, 60 and 45
    // percent of a screen recording written at AVFoundation's default quality, and the size grows steeply above 0.7
    // while it hardly shrinks below 0.3.
    private func videoQuality(of quality: EncodeQuality) -> Double {
        switch quality {
        case .high:
            0.7

        case .medium:
            0.5

        case .low:
            0.3
        }
    }
}
