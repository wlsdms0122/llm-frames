//
//  MediaKind+Document.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The kind a document that passed the checks is used as. The checker lets only these kinds through, and image and
// layout documents both draw a picture.
extension MediaKind {
    // MARK: - Property
    // MARK: - Initializer
    init(document: JSONValue) {
        self = document.objectValue?["kind"] == .string("sequence") ? .sequence : .image
    }

    // MARK: - Public
    // MARK: - Private
}
