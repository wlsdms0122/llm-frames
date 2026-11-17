//
//  BannerLine.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One line of a banner: its text and the style it names, nil when it is set in `banner`.
struct BannerLine: Equatable, Sendable {
    // MARK: - Property
    let text: String
    let style: String?

    // MARK: - Initializer
    init(
        text: String,
        style: String?
    ) {
        self.text = text
        self.style = style
    }

    // MARK: - Public
    // MARK: - Private
}
