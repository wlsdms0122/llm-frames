//
//  ThemeReference.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A document's `theme`: a theme file by name or path, or a theme object written in place.
enum ThemeReference: Equatable, Sendable {
    case named(String)
    case object(JSONValue)
}
