//
//  ResolvedMatte.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A transition's luma matte: its pinned media, the width of its edge, whether dark and light are swapped, and its ease.
struct ResolvedMatte: Equatable, Sendable {
    // MARK: - Property
    let media: PinnedMedia
    let softness: Double
    let isInverted: Bool
    let ease: Ease

    // MARK: - Initializer
    init(
        media: PinnedMedia,
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
