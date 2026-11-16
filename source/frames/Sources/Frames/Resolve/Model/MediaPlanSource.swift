//
//  MediaPlanSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What plan media is: a file, a nested sequence with its time plan, or an image or layout document, which draws
// its picture.
enum MediaPlanSource: Equatable, Sendable {
    case file(MediaFile)
    case sequence(TimePlan)
    case picture(NestedPicture)
}
