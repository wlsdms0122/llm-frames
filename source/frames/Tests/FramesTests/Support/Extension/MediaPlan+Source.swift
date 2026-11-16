//
//  MediaPlan+Source.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

@testable import Frames

// Lets a test reach the file or the nested sequence a media is, and nil when it is another.
extension MediaPlan {
    // MARK: - Property
    var file: MediaFile? {
        guard case let .file(file) = source else { return nil }

        return file
    }

    var sequence: TimePlan? {
        guard case let .sequence(plan) = source else { return nil }

        return plan
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
