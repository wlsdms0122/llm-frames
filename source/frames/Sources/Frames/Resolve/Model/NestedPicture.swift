//
//  NestedPicture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// An image or layout document met where media is written, with the theme it resolves on and what time knows of the
// media it takes: an image document's source, or a layout's items in order.
struct NestedPicture: Equatable, Sendable {
    // MARK: - Property
    let document: PictureDocument
    let theme: MergedTheme
    let media: [MediaPlan]

    // MARK: - Initializer
    init(
        document: PictureDocument,
        theme: MergedTheme,
        media: [MediaPlan]
    ) {
        self.document = document
        self.theme = theme
        self.media = media
    }

    // MARK: - Public
    // MARK: - Private
}
