//
//  FrameSourceArgument.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// What the argument of `sheet`, `extract` or `loudness` names: a `.json` file, compared ignoring case, a pack template
// or `-` is a document argument, and any other absolute path a medium, a video or an image sequence's directory.
enum FrameSourceArgument: Equatable, Sendable {
    case document(String)
    case medium(path: String)

    // MARK: - Property
    // MARK: - Initializer
    init(_ argument: String) {
        guard argument.hasPrefix("/"), URL(fileURLWithPath: argument).pathExtension.lowercased() != "json" else {
            self = .document(argument)
            return
        }

        self = .medium(path: argument)
    }

    // MARK: - Public
    // MARK: - Private
}
