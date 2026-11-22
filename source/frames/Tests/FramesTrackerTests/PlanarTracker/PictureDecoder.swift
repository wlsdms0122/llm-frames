//
//  PictureDecoder.swift
//  FramesTrackerTests
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import Frames
import FramesAVFoundation

// A decoder whose frame i of any file is the i-th of `pictures`, grey values as 8-bit components, so a tracker reads a
// plane movie's frames as drawn, with no coding between. The rest it reads as the `avfoundation` decoder does.
struct PictureDecoder: MediaDecoder {
    // MARK: - Property
    private let pictures: [Bitmap]
    private let decoder = AVFoundationDecoder()

    var largestPictureSide: Int {
        decoder.largestPictureSide
    }

    // MARK: - Initializer
    // Each of `pictures` holds `width` times `height` grey values row by row from the top left.
    init(
        pictures: [[Float]],
        width: Int,
        height: Int
    ) {
        self.pictures = pictures.map { values in
            var bytes = [UInt8](repeating: 255, count: values.count * 4)
            for (index, value) in values.enumerated() {
                let code = UInt8((value * 255).rounded())
                bytes[index * 4] = code
                bytes[index * 4 + 1] = code
                bytes[index * 4 + 2] = code
            }

            return Bitmap(width: width, height: height, depth: .eight, bytesPerRow: width * 4, pixels: Data(bytes))
        }
    }

    // MARK: - Public
    func picture(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> Bitmap {
        pictures[index]
    }

    func picture(
        of file: MediaFile,
        region: PageRegion,
        scale: Double,
        reading: PictureReading
    ) throws -> Bitmap {
        try decoder.picture(of: file, region: region, scale: scale, reading: reading)
    }

    func pageSize(of file: MediaFile) throws -> Size {
        try decoder.pageSize(of: file)
    }

    func colorReading(of file: MediaFile) throws -> ColorReading {
        try decoder.colorReading(of: file)
    }

    func check(
        _ file: MediaFile,
        reading: PictureReading?
    ) throws {
        try decoder.check(file, reading: reading)
    }

    func sound(
        of file: MediaFile,
        from start: Double,
        to end: Double
    ) throws -> SoundBuffer {
        try decoder.sound(of: file, from: start, to: end)
    }

    // MARK: - Private
}
