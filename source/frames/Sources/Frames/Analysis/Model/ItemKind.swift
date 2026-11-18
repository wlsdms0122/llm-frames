//
//  ItemKind.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a reported item draws, as `evaluate` and `locate` name it under `item`: a display list item kind of FRAMES-20,
// or a list's background.
package enum ItemKind: String, Equatable, Sendable {
    case picture
    case path
    case glyphs
    case adjust
    case background

    // MARK: - Property
    // MARK: - Initializer
    init(content: DisplayContent) {
        switch content {
        case .picture:
            self = .picture

        case .path:
            self = .path

        case .glyphs:
            self = .glyphs

        case .adjust:
            self = .adjust
        }
    }

    // MARK: - Public
    // MARK: - Private
}
