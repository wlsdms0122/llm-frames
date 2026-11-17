//
//  FrameSourceArgument.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// What the argument of `sheet` or `extract` names frames from: a `.json` file, compared ignoring case, a pack template
// or `-` is a document argument, and any other absolute path a video.
enum FrameSourceArgument: Equatable, Sendable {
    case document(String)
    case video(path: String)

    // MARK: - Property
    // MARK: - Initializer
    init(_ argument: String) {
        guard argument.hasPrefix("/"), URL(fileURLWithPath: argument).pathExtension.lowercased() != "json" else {
            self = .document(argument)
            return
        }

        self = .video(path: argument)
    }

    // MARK: - Public
    // MARK: - Private
}
