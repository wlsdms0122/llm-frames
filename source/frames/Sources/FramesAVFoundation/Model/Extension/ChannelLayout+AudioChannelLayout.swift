//
//  ChannelLayout+AudioChannelLayout.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AudioToolbox
import Frames

// The speakers a Core Audio channel layout names, by a layout tag, a channel bitmap or channel descriptions. A layout
// naming another number of channels than the track carries names none of them, so the count's own layout stands.
extension ChannelLayout {
    // MARK: - Property
    // MARK: - Initializer
    init(
        audioChannelLayout layout: UnsafePointer<AudioChannelLayout>,
        channels: Int
    ) {
        let labels = Self.audioChannelLabels(of: layout).map(ChannelLabel.init(audioChannelLabel:))

        self = labels.count == channels ? ChannelLayout(labels: labels) : ChannelLayout(channels: channels)
    }

    // MARK: - Public
    // MARK: - Private
    private static func audioChannelLabels(of layout: UnsafePointer<AudioChannelLayout>) -> [AudioChannelLabel] {
        switch layout.pointee.mChannelLayoutTag {
        case kAudioChannelLayoutTag_UseChannelDescriptions:
            describedLabels(of: layout)

        case kAudioChannelLayoutTag_UseChannelBitmap:
            expandedLabels(
                property: kAudioFormatProperty_ChannelLayoutForBitmap,
                specifier: layout.pointee.mChannelBitmap.rawValue
            )

        case let tag:
            expandedLabels(property: kAudioFormatProperty_ChannelLayoutForTag, specifier: tag)
        }
    }

    // The labels of the channel descriptions Core Audio gives for a layout tag or a bitmap, both 32 bit specifiers.
    private static func expandedLabels(
        property: AudioFormatPropertyID,
        specifier: UInt32
    ) -> [AudioChannelLabel] {
        var specifier = specifier
        let specifierSize = UInt32(MemoryLayout<UInt32>.size)
        var size: UInt32 = 0
        guard AudioFormatGetPropertyInfo(property, specifierSize, &specifier, &size) == noErr, size > 0 else {
            return []
        }

        let expanded = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioChannelLayout>.alignment
        )
        defer { expanded.deallocate() }
        guard AudioFormatGetProperty(property, specifierSize, &specifier, &size, expanded) == noErr else { return [] }

        return describedLabels(of: expanded.assumingMemoryBound(to: AudioChannelLayout.self))
    }

    // The descriptions run on past the end of the declared struct, one per channel.
    private static func describedLabels(of layout: UnsafePointer<AudioChannelLayout>) -> [AudioChannelLabel] {
        let count = Int(layout.pointee.mNumberChannelDescriptions)
        let offset = MemoryLayout<AudioChannelLayout>.offset(of: \.mChannelDescriptions)!
        let descriptions = UnsafeRawPointer(layout)
            .advanced(by: offset)
            .assumingMemoryBound(to: AudioChannelDescription.self)

        return (0..<count).map { descriptions[$0].mChannelLabel }
    }
}
