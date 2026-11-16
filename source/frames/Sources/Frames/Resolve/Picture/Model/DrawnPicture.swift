//
//  DrawnPicture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The picture a drawing step shows: a media file at a media second, whose frame is the one whose presentation interval
// holds it, an image or layout document's plan, or a compound clip's at a time of its own.
enum DrawnPicture: Equatable, Sendable {
    case media(ResolvedMedia, time: Double)
    case picture(PicturePlan)
    case sequence(SequencePlan, time: Double)
}
