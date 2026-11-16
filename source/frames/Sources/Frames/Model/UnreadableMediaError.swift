//
//  UnreadableMediaError.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A media file that is there but the probe cannot read, with the probe's failure. It names no place: the caller that
// knows where the file is named stops there.
struct UnreadableMediaError: Error {
    // MARK: - Property
    let reason: any Error

    // MARK: - Initializer
    init(reason: any Error) {
        self.reason = reason
    }

    // MARK: - Public
    // MARK: - Private
}
