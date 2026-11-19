//
//  VocabularyTable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum VocabularyTable {
    static let placementNames = [
        "top-left", "top", "top-right",
        "left", "center", "right",
        "bottom-left", "bottom", "bottom-right"
    ]
    static let sides = ["left", "right", "top", "bottom"]
    static let shapes = ShapeKind.allCases.map(\.rawValue)
    static let blendModes = [
        "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge",
        "color-burn", "hard-light", "soft-light", "difference", "exclusion", "plus-lighter",
        "hue", "saturation", "color", "luminosity"
    ]
    static let conforms = ["fit", "fill"]
    static let parameterTypes = ["video", "sequence", "image", "audio", "text", "color", "number", "choice"]
    static let easeNames = ["linear", "ease-in", "ease-out", "ease-in-out", "back-out", "bounce-out", "step"]
}
