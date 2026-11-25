//
//  RenderPipelineTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames

@Suite("RenderPipeline Tests")
struct RenderPipelineTests {
    // MARK: - Property
    private let master = "/abs/out.mov"
    private let delivery = "/abs/out.mp4"
    private let image = "/abs/out.png"
    private let size = Size(width: 40, height: 30)
    private let whole = Rectangle(x: 0, y: 0, width: 40, height: 30)
    private let video = PinnedMedia(
        source: .file(PinnedFile(path: "/abs/run.mp4", sha256: "sha256-of-/abs/run.mp4"), frameTimes: [0, 0.5, 1, 1.5])
    )
    private let music = PinnedMedia(source: .file(PinnedFile(path: "/abs/bgm.m4a", sha256: "sha256-of-/abs/bgm.m4a"), frameTimes: nil))

    // MARK: - Initializer
    // MARK: - Test
    @Test("every role checks before the first frame, in order, and then each frame is drawn once and goes to every writer in order, each finished after its last frame")
    func checksBeforeFirstFrame() throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)
        let sequence = sequence(fps: 2, duration: 1, audio: soundtrack)

        // When
        try sut.render(sequence, to: master, at: nil, delivery: delivery)

        // Then
        let silence = SoundBuffer(sampleRate: 48_000, channels: 2, samples: Array(repeating: 0, count: 96_000))
        let opened = checks(of: sequence) + [
            .mix(length: 48_000),
            .videoWriter(.master(path: master, alpha: false), size: size, fps: 2, sound: silence),
            .videoWriter(.delivery(path: delivery), size: size, fps: 2, sound: silence)
        ]
        let written = Array(log.calls.dropFirst(opened.count))
        #expect(Array(log.calls.prefix(opened.count)) == opened)
        #expect(written.filter { $0 == .draw(frame: 0) || $0 == .draw(frame: 1) } == [.draw(frame: 0), .draw(frame: 1)])
        #expect(calls(of: master, in: written) == [
            .append(path: master, frame: 0),
            .append(path: master, frame: 1),
            .finish(path: master)
        ])
        #expect(calls(of: delivery, in: written) == [
            .append(path: delivery, frame: 0),
            .append(path: delivery, frame: 1),
            .finish(path: delivery)
        ])
        #expect(Array(written.suffix(2)) == [.finish(path: master), .finish(path: delivery)])
    }

    @Test("a role that refuses stops the render after the checks before it, with nothing drawn or written", arguments: [
        (RoleRefusal.decoder, 1),
        (RoleRefusal.mixer, 3),
        (RoleRefusal.renderer, 4),
        (RoleRefusal.encoder, 6)
    ])
    func stopsOnRefusal(
        refusal: RoleRefusal,
        checkCount: Int
    ) {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log, refusal: refusal)
        let sequence = sequence(fps: 2, duration: 1, audio: soundtrack)

        // When
        #expect(throws: refusal) {
            try sut.render(sequence, to: master, at: nil, delivery: delivery)
        }

        // Then
        #expect(log.calls == Array(checks(of: sequence).prefix(checkCount)))
    }

    @Test("a renderer that cannot draw samples refuses before the first frame is drawn, naming the first frame that holds them")
    func namesSampledFrame() throws {
        // Given
        let log = RoleCallLog()
        let sut = RenderPipeline(
            decoder: RecordingDecoder(log: log),
            renderer: RecordingRenderer(log: log, refusesSamples: true),
            mixer: RecordingMixer(log: log),
            encoder: RecordingEncoder(log: log),
            hasher: FileHashTable()
        )
        let sequence = try ResolvedSequence(plan: Fixture.documentPlanner.plan(Fixture.json(#"""
            { "kind": "sequence", "format": { "size": [40, 30], "fps": 4 },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 1 } ],
              "clips": [ { "kind": "rect", "fill": "#FF0000", "at": [0.5, 1], "width": 10, "height": 10, "motionBlur": true,
                           "keyframes": [ { "at": 0.5, "position": [10, 15] }, { "at": 1, "position": [30, 15] } ] } ] }
            """#)), hashes: FileHashTable())

        // When
        let error = #expect(throws: RenderError.self) {
            try sut.render(sequence, to: master, at: nil, delivery: nil)
        }

        // Then
        #expect(error == .sampledFrame(time: 0.5, reason: "\(RoleRefusal.renderer)"))
        #expect(log.calls == [
            .checkPlan(MixPlanner().mix(of: sequence)),
            .checkList(frame: 0),
            .checkList(frame: 1),
            .checkList(frame: 2)
        ])
    }

    @Test("a pinned file whose hash changed is refused at the place that pins it before any role is called")
    func refusesChangedHash() {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log, hasher: FileHashTable(["/abs/run.mp4": "a different digest"]))

        // When
        #expect(throws: PinnedReferenceError.changedFile(path: "/abs/run.mp4", place: "storyline[0]")) {
            try sut.render(sequence(fps: 2, duration: 1), to: master, at: nil, delivery: nil)
        }

        // Then
        #expect(log.calls.isEmpty)
    }

    @Test("a picture no fixed formula converts, read where no colour space is written, is refused before a frame is drawn")
    func refusesUnconvertibleColor() {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log, colorReading: .platform)

        // When
        #expect(throws: RoleRefusal.decoder) {
            try sut.render(sequence(fps: 2, duration: 1), to: master, at: nil, delivery: nil)
        }

        // Then
        #expect(log.calls == [.checkMedia(path: "/abs/run.mp4")])
    }

    @Test("a picture no fixed formula converts is rendered where its place writes the colour space it is in")
    func rendersUnconvertibleColorInWrittenSpace() throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log, colorReading: .platform)

        // When
        try sut.render(sequence(fps: 2, duration: 1, mediaColorSpace: .rec709), to: master, at: nil, delivery: nil)

        // Then
        #expect(log.calls.contains(.finish(path: master)))
    }

    @Test("a still read in the colour space its place writes and as a displacement map by its tags is checked in each reading and rendered")
    func rendersStillAsMediaAndDisplacementMap() throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)
        let card = PinnedFile(path: "/abs/card.png", sha256: "sha256-of-/abs/card.png")
        let sequence = sequence(
            fps: 2,
            duration: 1,
            media: PinnedMedia(source: .file(card, frameTimes: nil)),
            mediaColorSpace: .rec709,
            filter: .filter([.displace(file: card, amount: 4, offset: Point(x: 0, y: 0))])
        )

        // When
        try sut.render(sequence, to: master, at: nil, delivery: nil)

        // Then
        #expect(log.calls.prefix(2) == [.checkMedia(path: "/abs/card.png"), .checkMedia(path: "/abs/card.png")])
        #expect(log.calls.contains(.finish(path: master)))
    }

    @Test("a file changed on disk since it was resolved is refused")
    func refusesChangedFile() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("run.mp4")
        try Data([1, 2, 3]).write(to: URL(fileURLWithPath: path))
        let pinned = PinnedMedia(source: .file(PinnedFile(path: path, sha256: try FileHasher().sha256(ofFile: path)), frameTimes: nil))
        try Data([1, 2, 4]).write(to: URL(fileURLWithPath: path))

        let log = RoleCallLog()
        let sut = pipeline(log: log, hasher: FileHasher())

        // When
        #expect(throws: PinnedReferenceError.changedFile(path: path, place: "storyline[0]")) {
            try sut.render(sequence(fps: 2, duration: 1, media: pinned), to: master, at: nil, delivery: nil)
        }

        // Then
        #expect(log.calls.isEmpty)
    }

    @Test("a pinned file that is gone is refused")
    func refusesMissingFile() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("gone.mp4")
        let pinned = PinnedMedia(source: .file(PinnedFile(path: path, sha256: String(repeating: "0", count: 64)), frameTimes: nil))

        let log = RoleCallLog()
        let sut = pipeline(log: log, hasher: FileHasher())

        // When
        #expect(throws: PinnedReferenceError.unreadableFile(path: path, place: "storyline[0]")) {
            try sut.render(sequence(fps: 2, duration: 1, media: pinned), to: master, at: nil, delivery: nil)
        }

        // Then
        #expect(log.calls.isEmpty)
    }

    // A minute at a written 29.97 mixes round(1799 × 1601.6) samples at the presented 30000 / 1001, 3 fewer than the
    // written rate gives.
    @Test("frames are drawn at k / fps while inside the sequence, and the sound lasts as long as they do at the presented rate", arguments: [
        (10.0, 1.0, 10, 48_000),
        (10.0, 1.01, 11, 52_800),
        (29.97, 2.0, 60, 96_096),
        (29.97, 60.0, 1799, 2_881_278),
        (10.0, 0.1 + 0.2, 3, 14_400),
        (30.0, 0.01, 1, 1_600)
    ])
    func countsFrames(
        fps: Double,
        duration: Double,
        count: Int,
        length: Int
    ) throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)

        // When
        try sut.render(sequence(fps: fps, duration: duration), to: master, at: nil, delivery: nil)

        // Then
        let drawn = log.calls.compactMap { call in
            if case let .draw(frame) = call { frame } else { nil }
        }
        #expect(drawn == Array(0..<count))
        #expect(Double(count - 1) / fps < duration)
        #expect(abs(Double(count) / fps - duration) <= 1 / fps)
        #expect(log.calls.contains(.mix(length: length)))
    }

    @Test("a sequence without sound is mixed from an empty plan, so its master carries a silent track")
    func mixesSilence() throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)

        // When
        try sut.render(sequence(fps: 2, duration: 1), to: master, at: nil, delivery: nil)

        // Then
        let silence = SoundBuffer(sampleRate: 48_000, channels: 2, samples: Array(repeating: 0, count: 96_000))
        #expect(log.calls.contains(.checkPlan(MixPlan(length: 48000, segments: []))))
        let target = EncodeTarget.master(path: master, alpha: false)
        #expect(log.calls.contains(.videoWriter(target, size: size, fps: 2, sound: silence)))
    }

    @Test("the master carries alpha when the background is not opaque", arguments: [
        ("#000000FF", false),
        ("#00000000", true),
        ("#10203080", true)
    ])
    func carriesAlphaFromBackground(
        background: String,
        alpha: Bool
    ) throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)
        let sequence = sequence(fps: 2, duration: 1, background: Color(written: background))

        // When
        try sut.render(sequence, to: master, at: nil, delivery: nil)

        // Then
        #expect(log.calls.contains(.checkTarget(.master(path: master, alpha: alpha))))
    }

    @Test("the delivery gets the same frames as the master, each drawn once")
    func deliversSameFrames() throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)

        // When
        try sut.render(sequence(fps: 10, duration: 0.5), to: master, at: nil, delivery: delivery)

        // Then
        let appended = { (path: String) in
            log.calls.compactMap { call in
                if case let .append(written, frame) = call, written == path { frame } else { nil }
            }
        }
        let drawn = log.calls.filter { call in
            if case .draw = call { true } else { false }
        }
        #expect(appended(master) == Array(0..<5))
        #expect(appended(delivery) == Array(0..<5))
        #expect(drawn.count == 5)
    }

    @Test("an MP4 output is a delivery alone: every frame is drawn once and goes to its one writer, and no master is written")
    func rendersDeliveryAlone() throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)
        let sequence = sequence(fps: 2, duration: 1, audio: soundtrack)

        // When
        try sut.render(sequence, to: delivery, at: nil, delivery: nil)

        // Then
        let silence = SoundBuffer(sampleRate: 48_000, channels: 2, samples: Array(repeating: 0, count: 96_000))
        let opened = Array(checks(of: sequence).prefix(5)) + [
            .checkTarget(.delivery(path: delivery)),
            .mix(length: 48_000),
            .videoWriter(.delivery(path: delivery), size: size, fps: 2, sound: silence)
        ]
        let written = Array(log.calls.dropFirst(opened.count))
        #expect(Array(log.calls.prefix(opened.count)) == opened)
        #expect(written.filter { $0 == .draw(frame: 0) || $0 == .draw(frame: 1) } == [.draw(frame: 0), .draw(frame: 1)])
        #expect(calls(of: delivery, in: written) == [
            .append(path: delivery, frame: 0),
            .append(path: delivery, frame: 1),
            .finish(path: delivery)
        ])
        #expect(written.count == 5)
    }

    @Test(
        "a PNG is the frame at `--at`, 0 when it is left out, checked and written once at 16 bits in the sequence's space",
        arguments: [
            (nil as Double?, 0),
            (1.25, 2),
            (1.99, 3)
        ]
    )
    func rendersFrameToPNG(
        time: Double?,
        frame: Int
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let sut = pipeline(log: log)
        let output = directory.file("out.png")

        // When
        try sut.render(sequence(fps: 2, duration: 2), to: output, at: time, delivery: nil)

        // Then
        let target = ImageTarget.png(path: output, size: size, depth: .sixteen)
        #expect(log.calls == [
            .checkMedia(path: "/abs/run.mp4"),
            .checkList(frame: frame),
            .checkImageTarget(target),
            .draw(frame: frame),
            .writeImageTarget(target, frame: frame)
        ])
    }

    @Test(
        "a master, a delivery beside it or alone and a PNG are written in the sequence's colour space at its peak",
        arguments: [(ColorSpace.rec2100PQ, 600 as Double?), (.rec2100HLG, nil), (.displayP3, nil)]
    )
    func rendersInColorSpace(
        colorSpace: ColorSpace,
        peak: Double?
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let log = RoleCallLog()
        let sut = pipeline(log: log)
        let sequence = sequence(fps: 2, duration: 1, colorSpace: colorSpace, peak: peak)
        let output = directory.file("out.png")
        let alone = "/abs/alone.mp4"

        // When
        try sut.render(sequence, to: master, at: nil, delivery: delivery)
        try sut.render(sequence, to: alone, at: nil, delivery: nil)
        try sut.render(sequence, to: output, at: 0, delivery: nil)

        // Then
        let conversion = ColorConversion(space: colorSpace, peak: peak)
        #expect(log.calls.contains(.checkTarget(.master(path: master, alpha: false, output: conversion))))
        #expect(log.calls.contains(.checkTarget(.delivery(path: delivery, output: conversion))))
        #expect(log.calls.contains(.checkTarget(.delivery(path: alone, output: conversion))))
        #expect(log.calls.contains(.checkImageTarget(.png(path: output, size: size, depth: .sixteen, output: conversion))))
    }

    @Test("`--at` outside the sequence stops before anything is read", arguments: [-0.5, 2, 3])
    func refusesTimeOutsideSequence(time: Double) {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)

        // When
        #expect(throws: ExportError.timeOutside(option: "--at", time: time, end: 2, kind: "sequence")) {
            try sut.render(sequence(fps: 2, duration: 2), to: image, at: time, delivery: nil)
        }

        // Then
        #expect(log.calls.isEmpty)
    }

    @Test("`--at` with a video, `--deliver` without a master, a delivery other than an MP4 and any other output stop", arguments: [
        ("/abs/out.mov", 0.5 as Double?, nil as String?, RenderError.timeOfVideo(path: "/abs/out.mov")),
        ("/abs/out.mp4", 0.5, nil, RenderError.timeOfVideo(path: "/abs/out.mp4")),
        ("/abs/out.png", nil, "/abs/out.mp4", RenderError.deliveryWithoutMaster(path: "/abs/out.mp4")),
        ("/abs/out.mp4", nil, "/abs/other.mp4", RenderError.deliveryWithoutMaster(path: "/abs/other.mp4")),
        ("/abs/out.mov", nil, "/abs/deliver.mov", RenderError.deliveryExtension(path: "/abs/deliver.mov")),
        ("/abs/out.gif", nil, nil, RenderError.outputExtension(path: "/abs/out.gif"))
    ])
    func refusesOutputs(
        output: String,
        time: Double?,
        delivery: String?,
        error: RenderError
    ) {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)

        // When
        #expect(throws: error) {
            try sut.render(sequence(fps: 2, duration: 1), to: output, at: time, delivery: delivery)
        }

        // Then
        #expect(log.calls.isEmpty)
    }

    @Test("a video's run gives its frame count and each file's encoding, the output first, and tells the recorder of every frame drawn in order")
    func reportsVideoRun() throws {
        // Given
        let progress = Locked<[RunProgress]>([])
        let recorder = RunRecorder(progress: { reached in progress.write { $0.append(reached) } })
        let sut = pipeline(log: RoleCallLog())

        // When
        let run = try sut.render(sequence(fps: 2, duration: 1.5), to: master, at: nil, delivery: delivery, recorder: recorder)

        // Then
        #expect(run.frames == 3)
        #expect(run.files.map(\.path) == [master, delivery])
        #expect(progress.read { $0.map(\.frame) } == [1, 2, 3])
        #expect(progress.read { $0.map(\.frames) } == [3, 3, 3])
    }

    @Test("a PNG's run is one frame and the file the encoder wrote, timed in waiting")
    func reportsImageRun() throws {
        // Given
        let directory = try TemporaryDirectory()
        let image = directory.file("out.png")
        let recorder = RunRecorder()
        let sut = pipeline(log: RoleCallLog())

        // When
        let run = try sut.render(sequence(fps: 2, duration: 1), to: image, at: 0.5, delivery: nil, recorder: recorder)

        // Then
        #expect(run == RenderRun(
            frames: 1,
            files: [FileEncoding(path: image, codec: "PNG", usesHardware: false, seconds: StageTimes())]
        ))
        #expect(recorder.waitingOnEncoder > 0)
    }

    // MARK: - Private
    // The calls a writer of the file at `path` took, in order.
    private func calls(
        of path: String,
        in calls: [RoleCall]
    ) -> [RoleCall] {
        calls.filter { call in
            switch call {
            case let .append(appended, _):
                appended == path

            case let .finish(finished):
                finished == path

            default:
                false
            }
        }
    }

    // The storyline entry's own sound and a sequence clip's music.
    private var soundtrack: [ResolvedSound] {
        [sound(video, place: "storyline[0]"), sound(music, place: "clips[0]")]
    }

    private func pipeline(
        log: RoleCallLog,
        refusal: RoleRefusal? = nil,
        hasher: any FileHashProvider = FileHashTable(),
        colorReading: ColorReading = .formulas(.srgb)
    ) -> RenderPipeline {
        RenderPipeline(
            decoder: RecordingDecoder(log: log, refuses: refusal == .decoder, colorReading: colorReading),
            renderer: RecordingRenderer(log: log, refuses: refusal == .renderer),
            mixer: RecordingMixer(log: log, refuses: refusal == .mixer),
            encoder: RecordingEncoder(log: log, refuses: refusal == .encoder),
            hasher: hasher
        )
    }

    // The checks of a two frame sequence of `video` and `music` rendered with a delivery: each media once, the plan,
    // each frame, and each target.
    private func checks(of sequence: ResolvedSequence) -> [RoleCall] {
        [
            .checkMedia(path: "/abs/run.mp4"),
            .checkMedia(path: "/abs/bgm.m4a"),
            .checkPlan(MixPlanner().mix(of: sequence)),
            .checkList(frame: 0),
            .checkList(frame: 1),
            .checkTarget(.master(path: master, alpha: false)),
            .checkTarget(.delivery(path: delivery))
        ]
    }

    // One storyline entry showing `media` over the whole sequence.
    private func sequence(
        fps: Double,
        duration: Double,
        background: Color = Color(written: "#000000"),
        media: PinnedMedia? = nil,
        mediaColorSpace: ColorSpace? = nil,
        filter: TimedValue = .off,
        audio: [ResolvedSound] = [],
        colorSpace: ColorSpace = .srgb,
        peak: Double? = nil
    ) -> ResolvedSequence {
        let entry = ResolvedStorylineClip(
            place: "storyline[0]",
            id: nil,
            media: .pinned(media ?? video),
            color: nil,
            colorSpace: mediaColorSpace,
            in: 0,
            out: duration,
            speed: 1,
            start: 0,
            end: duration,
            crop: .keyframes([Keyframe(at: 0, value: Crop(whole))]),
            track: nil,
            filter: filter,
            transition: nil,
            filling: size
        )

        return ResolvedSequence(
            format: ResolvedFormat(
                size: size,
                fps: fps,
                duration: duration,
                background: background,
                conform: .fit,
                colorSpace: colorSpace,
                peak: peak
            ),
            storyline: [entry],
            clips: [],
            audio: audio
        )
    }

    private func sound(
        _ media: PinnedMedia,
        place: String
    ) -> ResolvedSound {
        ResolvedSound(
            place: place,
            media: media,
            nested: [],
            played: PlayedRange(
                map: TimeMap(origin: 0, in: 0, speed: 1),
                out: 1,
                loop: false
            ),
            start: 0,
            end: 1,
            audible: TimeRange(start: 0, end: 1),
            volume: [Keyframe(at: 0, value: 1)],
            pan: [Keyframe(at: 0, value: 0)],
            fadeIn: nil,
            fadeOut: nil,
            incoming: nil,
            outgoing: nil
        )
    }
}
