//
//  GlyphLayer.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// One step of a glyphs item's drawing order, the only one a unit's item draws, so that the passes over a title's units
// keep every highlight under every underline, stroke and fill of the title.
package enum GlyphLayer: String, CaseIterable, Equatable, Sendable {
    case highlights
    case underlines
    case strokes
    case fills
}
