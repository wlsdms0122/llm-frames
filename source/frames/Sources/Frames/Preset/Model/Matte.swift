//
//  Matte.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct Matte: Equatable, Sendable {
    // MARK: - Property
    let media: String
    let softness: Double
    let isInverted: Bool
    let ease: Ease

    // MARK: - Initializer
    init(
        media: String,
        softness: Double,
        isInverted: Bool,
        ease: Ease
    ) {
        self.media = media
        self.softness = softness
        self.isInverted = isInverted
        self.ease = ease
    }

    // MARK: - Public
    // MARK: - Private
}
