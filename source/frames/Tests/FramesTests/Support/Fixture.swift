//
//  Fixture.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

@testable import Frames

enum Fixture {
    static func json(_ text: String) throws -> JSONValue {
        try JSONReader().read(text)
    }

    static func object(_ text: String) throws -> JSONObject {
        try json(text).objectValue ?? JSONObject()
    }

    static let mediaKinds = MediaKindTable([
        "/abs/run.mp4": .video,
        "/abs/card.png": .image,
        "/abs/log.png": .image,
        "/abs/light-leak.mov": .video,
        "/abs/bgm.m4a": .audio,
        "/abs/ding.wav": .audio,
        "/abs/shot.png": .image,
        "/abs/before.png": .image,
        "/abs/after.png": .image,
        "pack/intro": .sequence,
        "pack/card": .image
    ])

    static let mediaFacts = MediaFactTable(
        files: [
            "/abs/run.mp4": ProbedMedia(kind: .video, duration: 30, fps: 29.97),
            "/abs/short.mp4": ProbedMedia(kind: .video, duration: 4, fps: 1, frames: [0, 1, 2, 3]),
            "/abs/light-leak.mov": ProbedMedia(kind: .video, duration: 4, fps: 23.976),
            "/abs/halfway.mp4": ProbedMedia(kind: .video, duration: 4, fps: 27.5),
            "/abs/card.png": ProbedMedia(kind: .image),
            "/abs/log.png": ProbedMedia(kind: .image),
            "/abs/bgm.m4a": ProbedMedia(kind: .audio, duration: 20),
            "/abs/ding.wav": ProbedMedia(kind: .audio, duration: 1.5),
            "/abs/intro.json": ProbedMedia(kind: .sequence)
        ],
        imageSequences: ["/abs/frames": 12]
    )

    static let presets = PresetTable(
        transitions: [
            "flash": transition(seconds: 0.5),
            "push-up": transition(seconds: 0.5),
            "wipe-right": transition(seconds: 1),
            "long": transition(seconds: 4)
        ],
        animations: [
            "pop": AnimationPreset(description: "", entrance: span(0.25), loop: nil, exit: nil),
            "fade": AnimationPreset(description: "", entrance: span(0.25), loop: nil, exit: span(0.25)),
            "stamp": AnimationPreset(description: "", entrance: span(0.25), loop: nil, exit: nil),
            "draw": AnimationPreset(description: "", entrance: span(0.5), loop: nil, exit: nil),
            "pulse": AnimationPreset(description: "", entrance: span(0.25), loop: span(1), exit: span(0.25))
        ]
    )

    static let planner = TimePlanner(mediaFacts: mediaFacts, presets: presets)

    private static func transition(seconds: Double) -> TransitionPreset {
        TransitionPreset(description: "", seconds: seconds, over: .incoming, incoming: nil, outgoing: nil, cover: nil, matte: nil)
    }

    private static func span(_ length: Double) -> AnimationSpan {
        AnimationSpan(length: length, span: Span(ease: .linear, keys: []))
    }
}
