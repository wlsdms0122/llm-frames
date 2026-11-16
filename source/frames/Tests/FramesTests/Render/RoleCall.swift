//
//  RoleCall.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames

// A call a recording role was given. A frame is named by its display list's seed, its number in the output.
enum RoleCall: Equatable {
    case checkMedia(path: String)
    case checkList(frame: Int)
    case checkPlan(MixPlan)
    case checkTarget(EncodeTarget)
    case mix(duration: Double)
    case draw(frame: Int)
    case writeImage(path: String, frame: Int)
    case videoWriter(EncodeTarget, size: Size, fps: Double, sound: SoundBuffer?)
    case append(path: String, frame: Int)
    case finish(path: String)
}
