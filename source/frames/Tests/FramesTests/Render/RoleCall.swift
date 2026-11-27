//
//  RoleCall.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

// A call a recording role was given. A frame is named by its display list's seed, its number in the output, and a draw
// names the frame drawn after it, nil where none is. `replace` is a write that found a file already at its path.
enum RoleCall: Equatable {
    case checkMedia(path: String)
    case readSound(path: String, from: Double, to: Double)
    case readPicture(path: String, frame: Int, play: MediaPlay, reading: PictureReading)
    case renderFrame(showing: [MediaFrame])
    case readPage(path: String, page: Int?, region: PageRegion, scale: Double, reading: PictureReading)
    case checkList(frame: Int)
    case checkPlan(MixPlan)
    case checkTarget(EncodeTarget)
    case checkImageTarget(ImageTarget)
    case checkSoundTarget(SoundTarget)
    case mix(length: Int)
    case draw(frame: Int, next: Int?)
    case writeAnalysisPicture(path: String, frame: Int, output: ColorConversion)
    case writeImageTarget(ImageTarget, frame: Int)
    case writeSound(SoundTarget, sound: SoundBuffer)
    case replace(path: String)
    case videoWriter(EncodeTarget, size: Size, fps: Double, sound: SoundBuffer?)
    case append(path: String, frame: Int)
    case finish(path: String)
}
