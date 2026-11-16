//
//  ContactSheetCell.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// One picture of a contact sheet with the label under it.
struct ContactSheetCell: Equatable, Sendable {
    // MARK: - Property
    let picture: PictureItemSource
    let label: String

    // MARK: - Initializer
    init(
        picture: PictureItemSource,
        label: String
    ) {
        self.picture = picture
        self.label = label
    }

    // A frame labelled with its time, rounded to the microsecond in its shortest form, as `2.5s`.
    init(_ frame: SampledFrame) {
        self.init(picture: frame.picture, label: "\(JSONValue.time(frame.time).written)s")
    }

    // MARK: - Public
    // MARK: - Private
}
