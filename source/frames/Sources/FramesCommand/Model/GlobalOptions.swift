//
//  GlobalOptions.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// The options given before the command: the theme and the name of each role and provider, nil where the default is
// taken, and all of them as written, which a tool is given unchanged.
struct GlobalOptions: Equatable, Sendable {
    // MARK: - Property
    static let none = GlobalOptions(
        theme: nil,
        decoder: nil,
        renderer: nil,
        mixer: nil,
        encoder: nil,
        ocr: nil,
        shaper: nil,
        tracker: nil,
        memory: nil,
        written: []
    )

    let theme: String?
    let decoder: String?
    let renderer: String?
    let mixer: String?
    let encoder: String?
    let ocr: String?
    let shaper: String?
    let tracker: String?
    // Nil where `--memory` is not written, so the run's limit is the default.
    let memory: MemorySize?
    let written: [String]

    // MARK: - Initializer
    init(
        theme: String?,
        decoder: String?,
        renderer: String?,
        mixer: String?,
        encoder: String?,
        ocr: String?,
        shaper: String?,
        tracker: String?,
        memory: MemorySize?,
        written: [String]
    ) {
        self.theme = theme
        self.decoder = decoder
        self.renderer = renderer
        self.mixer = mixer
        self.encoder = encoder
        self.ocr = ocr
        self.shaper = shaper
        self.tracker = tracker
        self.memory = memory
        self.written = written
    }

    // MARK: - Public
    // MARK: - Private
}
