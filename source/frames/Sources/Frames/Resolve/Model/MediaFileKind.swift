//
//  MediaFileKind.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// What a media file is, with what a decoder and resolve read of it. A video has the media time of each of its frames,
// and an image sequence the file of each frame in frame order with the media time of each. A page is the page of a PDF
// counted from 1, whose colour reading is always `srgb` (`MediaFile.colorReading`). `sound` is a file read for its
// sound alone: a sound file, or a file whose frames nothing names, as `loudness` measures one. `fps` is the nominal
// frame rate, `size` the picture's size as it is displayed and `colorReading` how a decoder takes the pictures to
// working values (FRAMES-26 Media), as the probe found them. They are nil where the file is named without its probe:
// by pinned media, which pins only its frames, or by `transcode` for a page, whose size the decoder reads.
package enum MediaFileKind: Equatable, Sendable {
    case video(frameTimes: [Double], fps: Double?, size: Size?, colorReading: ColorReading?)
    case still(size: Size?, colorReading: ColorReading?)
    case imageSequence(
        frameFiles: [String],
        frameTimes: [Double],
        fps: Double?,
        size: Size?,
        colorReading: ColorReading?
    )
    case page(Int, size: Size?)
    case sound
}
