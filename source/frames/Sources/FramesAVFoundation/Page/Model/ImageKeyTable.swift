//
//  ImageKeyTable.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

// The keys of an image's dictionary that say what it paints in (ISO 32000-1 8.9.5 and 8.9.7): whether it is a stencil
// mask, and its colour space. An inline image may write each in its abbreviated form.
struct ImageKeyTable {
    // MARK: - Property
    static let xObject = ImageKeyTable(mask: ["ImageMask"], colorSpace: ["ColorSpace"])
    static let inline = ImageKeyTable(mask: ["ImageMask", "IM"], colorSpace: ["ColorSpace", "CS"])

    let mask: [String]
    let colorSpace: [String]

    // MARK: - Initializer
    private init(
        mask: [String],
        colorSpace: [String]
    ) {
        self.mask = mask
        self.colorSpace = colorSpace
    }

    // MARK: - Public
    // MARK: - Private
}
