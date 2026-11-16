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

// How AVFoundation writes an encode target. A master is a QuickTime movie of ProRes 4444 with premultiplied alpha, or
// ProRes 422 HQ, and 24-bit integer linear PCM. A delivery is an MPEG-4 file of H.264 at quality 1.0, which the H.264
// encoder honours, and AAC at a constant 256 kbps. Every video is tagged BT.709 primaries, the sRGB transfer and the
// BT.709 matrix. Sound is 48 kHz stereo. ProRes takes 16-bit RGBA frames. H.264 takes 8-bit BGRA, which its hardware
// encoder reads natively, since 16-bit RGBA handed to it can fault the hardware encoder.
struct TargetFormat: Equatable, Sendable {
    // MARK: - Property
    private static let sampleRate = 48_000
    private static let channels = 2
    private static let aacBitRate = 256_000

    let path: String
    let fileType: AVFileType
    let codec: AVVideoCodecType
    let codecType: CMVideoCodecType
    let codecName: String
    let keepsAlpha: Bool
    let pixelFormat: OSType

    var colorProperties: [String: String] {
        [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: kCVImageBufferTransferFunction_sRGB as String,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]
    }

    var audioSettings: [String: Any] {
        var channelLayout = AudioChannelLayout()
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        let common: [String: Any] = [
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: Self.channels,
            AVChannelLayoutKey: Data(bytes: &channelLayout, count: MemoryLayout<AudioChannelLayout>.size)
        ]
        let specific: [String: Any] = fileType == .mov
            ? [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            : [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVEncoderBitRateKey: Self.aacBitRate,
                AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_Constant
            ]

        return common.merging(specific) { first, _ in first }
    }

    // MARK: - Initializer
    init(target: EncodeTarget) {
        switch target {
        case let .master(path, alpha):
            self.path = path
            fileType = .mov
            codec = alpha ? .proRes4444 : .proRes422HQ
            codecType = alpha ? kCMVideoCodecType_AppleProRes4444 : kCMVideoCodecType_AppleProRes422HQ
            codecName = alpha ? "ProRes 4444" : "ProRes 422 HQ"
            keepsAlpha = alpha
            pixelFormat = kCVPixelFormatType_64RGBALE

        case let .delivery(path):
            self.path = path
            fileType = .mp4
            codec = .h264
            codecType = kCMVideoCodecType_H264
            codecName = "H.264"
            keepsAlpha = false
            pixelFormat = kCVPixelFormatType_32BGRA
        }
    }

    // MARK: - Public
    func videoSettings(
        width: Int,
        height: Int
    ) -> [String: Any] {
        let compression: [String: Any] = switch codec {
        case .proRes4444:
            [kVTCompressionPropertyKey_AlphaChannelMode as String: kVTAlphaChannelMode_PremultipliedAlpha as String]

        case .h264:
            [AVVideoQualityKey: 1.0]

        default:
            [:]
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
}
