//
//  Fixture.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation

@testable import Frames

enum Fixture {
    static func json(_ text: String) throws -> JSONValue {
        try JSONReader().read(text)
    }

    static func object(_ text: String) throws -> JSONObject {
        try json(text).objectValue ?? JSONObject()
    }

    static let mediaKinds = MediaKindTable(
        [
            "/abs/run.mp4": .video,
            "/abs/card.png": .image,
            "/abs/log.png": .image,
            "/abs/light-leak.mov": .video,
            "/abs/bgm.m4a": .audio,
            "/abs/ding.wav": .audio,
            "/abs/shot.png": .image,
            "/abs/before.png": .image,
            "/abs/after.png": .image
        ],
        templates: ["pack/intro", "pack/card"]
    )

    // `/abs/run.mp4` and the audio files hold sound, and the other videos are silent.
    static let mediaFacts = MediaFactTable(
        files: [
            "/abs/run.mp4": ProbedMedia(
                kind: .video,
                duration: 30,
                fps: 29.97,
                size: Size(width: 1080, height: 1920),
                sound: ProbedSound(channels: 2, sampleRate: 48000)
            ),
            "/abs/short.mp4": ProbedMedia(
                kind: .video,
                duration: 4,
                fps: 1,
                frames: [0, 1, 2, 3],
                size: Size(width: 1080, height: 1920)
            ),
            "/abs/light-leak.mov": ProbedMedia(kind: .video, duration: 4, fps: 23.976, size: Size(width: 1920, height: 1080)),
            "/abs/halfway.mp4": ProbedMedia(kind: .video, duration: 4, fps: 27.5, size: Size(width: 1079, height: 1919)),
            "/abs/card.png": ProbedMedia(kind: .image, size: Size(width: 1080, height: 1350)),
            "/abs/log.png": ProbedMedia(kind: .image, size: Size(width: 1080, height: 1350)),
            "/abs/bgm.m4a": ProbedMedia(
                kind: .audio,
                duration: 20,
                sound: ProbedSound(channels: 2, sampleRate: 48000)
            ),
            "/abs/ding.wav": ProbedMedia(
                kind: .audio,
                duration: 1.5,
                sound: ProbedSound(channels: 1, sampleRate: 44100)
            ),
            "/abs/screen.mp4": ProbedMedia(
                kind: .video,
                duration: 4,
                fps: 10,
                frames: screenFrameTimes,
                size: Size(width: 1206, height: 2622)
            ),
            "/abs/page.png": ProbedMedia(kind: .image, size: Size(width: 1000, height: 800)),
            "/abs/strip.png": ProbedMedia(kind: .image, size: Size(width: 1000, height: 1)),
            "/abs/leak.mov": ProbedMedia(
                kind: .video,
                duration: 2,
                fps: 2,
                frames: [0, 0.5, 1, 1.5],
                size: Size(width: 1920, height: 1080)
            ),
            "/abs/matte.png": ProbedMedia(kind: .image, size: Size(width: 1080, height: 1920))
        ],
        imageSequences: ["/abs/frames": imageSequenceFiles]
    )

    // Twelve frames in natural order, so frame 10 comes after frame 9.
    static let imageSequenceFiles = (1...12).map { "/abs/frames/frame-\($0).png" }

    // A screen recording at 10 frames a second, whose frame i starts at media second i / 10.
    static let screenFrameTimes = (0..<40).map { Double($0) / 10 }

    static let presets = PresetTable(
        transitions: [
            "frames/flash": transition(seconds: 0.5),
            "frames/push-up": transition(seconds: 0.5),
            "frames/wipe-right": transition(seconds: 1),
            "mine/long": transition(seconds: 4),
            "mine/same-take": transition(seconds: 1, audio: .constantGain)
        ],
        animations: [
            "frames/pop": AnimationPreset(description: "", entrance: span(0.25), loop: nil, exit: nil),
            "frames/fade": AnimationPreset(description: "", entrance: span(0.25), loop: nil, exit: span(0.25)),
            "frames/stamp": AnimationPreset(description: "", entrance: span(0.25), loop: nil, exit: nil),
            "frames/draw": AnimationPreset(description: "", entrance: span(0.5), loop: nil, exit: nil),
            "frames/pulse": AnimationPreset(description: "", entrance: span(0.25), loop: span(1), exit: span(0.25))
        ],
        filters: [
            "frames/warm": FilterPreset(description: "", operations: []),
            "mine/grade": FilterPreset(description: "", operations: [.saturation(amount: 1.25), .blur(radius: 4)])
        ]
    )

    // No pack is installed or shipped, so only absolute paths name anything.
    static let library = ReferenceLibrary(
        packs: PackLibrary(installed: emptyDirectory, shipped: emptyDirectory),
        mediaFacts: mediaFacts
    )

    static let planner = TimePlanner(mediaFacts: mediaFacts, presets: presets, library: library)

    // "Send" is on every frame of `/abs/short.mp4`, and "Total" on every frame of `/abs/screen.mp4`.
    static let ocr = OCRTable([
        "/abs/short.mp4": [(from: 0, lines: [RecognisedLine(text: "Send", rectangle: send)])],
        "/abs/screen.mp4": [(from: 0, lines: [RecognisedLine(text: "Total", rectangle: total)])]
    ])
    static let send = Rectangle(x: 400, y: 1200, width: 200, height: 60)
    static let total = Rectangle(x: 100, y: 100, width: 200, height: 40)

    // The target is followed on every frame and holds still.
    static let tracker = TrackerTable(frameTimes: ["/abs/screen.mp4": screenFrameTimes, "/abs/short.mp4": [0, 1, 2, 3]])

    static let shaper = ShaperTable()

    static let sequencePlanner = SequencePlanner(
        ocr: ocr,
        tracker: tracker,
        shaper: shaper,
        presets: presets,
        library: library
    )

    static let documentPlanner = DocumentPlanner(
        mediaFacts: mediaFacts,
        presets: presets,
        ocr: ocr,
        tracker: tracker,
        shaper: shaper,
        library: library
    )

    private static let emptyDirectory: URL = {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("frames-empty-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private static func transition(
        seconds: Double,
        audio: CrossfadeCurve = .constantPower
    ) -> TransitionPreset {
        TransitionPreset(
            description: "",
            seconds: seconds,
            over: .incoming,
            audio: audio,
            incoming: nil,
            outgoing: nil,
            cover: nil,
            matte: nil
        )
    }

    private static func span(_ length: Double) -> AnimationSpan {
        AnimationSpan(length: length, span: Span(ease: .linear, keys: []))
    }
}
