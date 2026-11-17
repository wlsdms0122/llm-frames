//
//  MediaPlanSource.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What plan media is: a file, or a nested sequence with its time plan.
enum MediaPlanSource: Equatable, Sendable {
    case file(MediaFile)
    case sequence(TimePlan)
}
