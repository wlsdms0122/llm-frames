//
//  ImageOperation.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One operation of an image document with its place, which messages name.
struct ImageOperation: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let content: ImageOperationContent

    // MARK: - Initializer
    init(
        place: Place,
        content: ImageOperationContent
    ) {
        self.place = place
        self.content = content
    }

    // MARK: - Public
    // MARK: - Private
}
