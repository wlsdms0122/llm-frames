//
//  FormatSize.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A written `format.size`: a frame of that size, or one measured from the content with a margin round it.
enum FormatSize: Equatable, Sendable {
    case fixed(Size)
    case content(margin: Margin)
}
