//
//  Matte.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A transition's luma matte as its preset writes it. `colorSpace` is the space its file is read in, nil where its tags
// apply.
struct Matte: Equatable, Sendable {
    // MARK: - Property
    let media: String
    let colorSpace: ColorSpace?
    let softness: Double
    let isInverted: Bool
    let ease: Ease

    // MARK: - Initializer
    init(
        media: String,
        colorSpace: ColorSpace? = nil,
        softness: Double,
        isInverted: Bool,
        ease: Ease
    ) {
        self.media = media
        self.colorSpace = colorSpace
        self.softness = softness
        self.isInverted = isInverted
        self.ease = ease
    }

    // MARK: - Public
    // MARK: - Private
}
