//
//  Roles.swift
//  FramesCommand
//
//  Created by JSilver on 11/17/26.
//

import Frames

// The roles and providers a command runs on, every one that reads media reading it through `decoder`, and the memory
// budget they and the command's run draw from.
struct Roles: Sendable {
    // MARK: - Property
    let budget: MemoryBudget
    let decoder: any MediaDecoder & MediaFactProvider
    let renderer: any Renderer
    let mixer: any Mixer
    let encoder: any Frames.Encoder
    let ocr: any OCRProvider
    let shaper: any ShapingProvider
    let tracker: any TrackerProvider

    // MARK: - Initializer
    init(
        budget: MemoryBudget,
        decoder: any MediaDecoder & MediaFactProvider,
        renderer: any Renderer,
        mixer: any Mixer,
        encoder: any Frames.Encoder,
        ocr: any OCRProvider,
        shaper: any ShapingProvider,
        tracker: any TrackerProvider
    ) {
        self.budget = budget
        self.decoder = decoder
        self.renderer = renderer
        self.mixer = mixer
        self.encoder = encoder
        self.ocr = ocr
        self.shaper = shaper
        self.tracker = tracker
    }

    // MARK: - Public
    // MARK: - Private
}
