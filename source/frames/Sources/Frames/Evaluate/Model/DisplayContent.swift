//
//  DisplayContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

package enum DisplayContent: Equatable, Sendable {
    case picture(PictureItem)
    case path(PathItem)
    case glyphs(GlyphsItem)
    case adjust(AdjustItem)
}
