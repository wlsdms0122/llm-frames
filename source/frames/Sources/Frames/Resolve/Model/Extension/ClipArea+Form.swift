//
//  ClipArea+Form.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A clip area as a document writes it, its padding a theme length times `lengthScale`. Any other form is not one.
extension ClipArea {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        form: AreaForm,
        lengthScale: Double
    ) {
        guard case let .clip(clip, padding) = form else { return nil }

        self.init(clip: clip, padding: padding * lengthScale)
    }

    // MARK: - Public
    // MARK: - Private
}
