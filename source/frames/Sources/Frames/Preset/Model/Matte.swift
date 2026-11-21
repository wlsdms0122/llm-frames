//
//  Matte.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A transition's luma matte as its preset writes it. `page` is the page of the PDF `media` names, nil where it names
// no page. `colorSpace` is the space its file is read in, nil where its tags apply.
struct Matte: Equatable, Sendable {
    // MARK: - Property
    let media: String
    let page: Int?
    let colorSpace: ColorSpace?
    let softness: Double
    let isInverted: Bool
    let ease: Ease

    // MARK: - Initializer
    init(
        media: String,
        page: Int? = nil,
        colorSpace: ColorSpace? = nil,
        softness: Double,
        isInverted: Bool,
        ease: Ease
    ) {
        self.media = media
        self.page = page
        self.colorSpace = colorSpace
        self.softness = softness
        self.isInverted = isInverted
        self.ease = ease
    }

    // MARK: - Public
    // MARK: - Private
}
