//
//  ProgressFormat.swift
//  FramesCommand
//
//  Created by JSilver on 11/25/26.
//

// How `render` writes its progress on standard error (FRAMES-23 Runs): a line `frame <k>/<n>`, a JSON object on a line,
// or nothing.
enum ProgressFormat: String, CaseIterable, Sendable {
    case text
    case json
    case none
}
