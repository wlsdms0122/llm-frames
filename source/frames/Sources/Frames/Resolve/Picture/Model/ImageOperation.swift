//
//  ImageOperation.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One operation of an image document with its place, which messages name, and its `id`.
struct ImageOperation: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let content: ImageOperationContent

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        content: ImageOperationContent
    ) {
        self.place = place
        self.id = id
        self.content = content
    }

    // MARK: - Public
    // MARK: - Private
}
