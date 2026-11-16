//
//  DisplayContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a display item draws.
enum DisplayContent: Equatable, Sendable {
    case picture(PictureItem)
    case fill(FillItem)
    case stroke(StrokeItem)
    case arrow(ArrowItem)
    case glyphs(GlyphsItem)
    case adjust(AdjustItem)
}
