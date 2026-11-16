//
//  PictureMatte.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A luma matte stretched over a picture's destination: the picture shows where the luminance of `frame` is below
// `progress`, with an edge `softness` wide (0 to 1 of the luminance range), dark and light swapped when `isInverted`.
struct PictureMatte: Equatable, Sendable {
    // MARK: - Property
    let frame: MediaFrame
    let progress: Double
    let softness: Double
    let isInverted: Bool

    // MARK: - Initializer
    init(
        frame: MediaFrame,
        progress: Double,
        softness: Double,
        isInverted: Bool
    ) {
        self.frame = frame
        self.progress = progress
        self.softness = softness
        self.isInverted = isInverted
    }

    // MARK: - Public
    // MARK: - Private
}
