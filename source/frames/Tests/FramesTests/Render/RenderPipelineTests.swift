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
        source: .file(PinnedFile(path: "/abs/run.mp4", sha256: "sha256-of-/abs/run.mp4")),
        frameTimes: [0, 0.5, 1, 1.5]
    )
    private let music = PinnedMedia(source: .file(PinnedFile(path: "/abs/bgm.m4a", sha256: "sha256-of-/abs/bgm.m4a")))

    // MARK: - Initializer
    // MARK: - Test
    @Test("every role checks before the first frame, in order, and then each frame goes to every writer")
    func checksBeforeFirstFrame() throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)
        let sequence = sequence(fps: 2, duration: 1, audio: soundtrack)

        // When
        try sut.render(sequence, to: master, at: nil, delivery: delivery)

        // Then
        let silence = SoundBuffer(sampleRate: 48_000, channels: 2, samples: Array(repeating: 0, count: 96_000))
        #expect(log.calls == checks(of: sequence) + [
            .mix(duration: 1),
            .videoWriter(.master(path: master, alpha: false), size: size, fps: 2, sound: silence),
            .videoWriter(.delivery(path: delivery), size: size, fps: 2, sound: silence),
            .draw(frame: 0),
            .append(path: master, frame: 0),
            .append(path: delivery, frame: 0),
            .draw(frame: 1),
            .append(path: master, frame: 1),
            .append(path: delivery, frame: 1),
            .finish(path: master),
            .finish(path: delivery)
        ])
    }

    @Test("a role that refuses stops the render after the checks before it, with nothing drawn or written", arguments: [
        (RoleRefusal.decoder, 1),
        (RoleRefusal.renderer, 3),
        (RoleRefusal.mixer, 5),
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

    @Test("a pinned file whose hash changed is refused at the place that pins it before any role is called")
    func refusesChangedHash() {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log, hasher: FileHashTable(["/abs/run.mp4": "a different digest"]))

        // When
        #expect(throws: RenderError.changedFile(path: "/abs/run.mp4", place: "storyline[0]")) {
            try sut.render(sequence(fps: 2, duration: 1), to: master, at: nil, delivery: nil)
        }

        // Then
        #expect(log.calls.isEmpty)
    }

    @Test("a file changed on disk since it was resolved is refused")
    func refusesChangedFile() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("run.mp4")
        try Data([1, 2, 3]).write(to: URL(fileURLWithPath: path))
        let pinned = PinnedMedia(source: .file(PinnedFile(path: path, sha256: try FileHasher().sha256(ofFile: path))))
        try Data([1, 2, 4]).write(to: URL(fileURLWithPath: path))

        let log = RoleCallLog()
        let sut = pipeline(log: log, hasher: FileHasher())

        // When
        #expect(throws: RenderError.changedFile(path: path, place: "storyline[0]")) {
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
        let pinned = PinnedMedia(source: .file(PinnedFile(path: path, sha256: String(repeating: "0", count: 64))))

        let log = RoleCallLog()
        let sut = pipeline(log: log, hasher: FileHasher())

        // When
        #expect(throws: RenderError.unreadableFile(path: path, place: "storyline[0]")) {
            try sut.render(sequence(fps: 2, duration: 1, media: pinned), to: master, at: nil, delivery: nil)
        }

        // Then
        #expect(log.calls.isEmpty)
    }

    @Test("frames are drawn at k / fps while inside the sequence, and the sound lasts as long as they do", arguments: [
        (10.0, 1.0, 10),
        (10.0, 1.01, 11),
        (29.97, 2.0, 60),
        (10.0, 0.1 + 0.2, 3),
        (30.0, 0.01, 1)
    ])
    func countsFrames(
        fps: Double,
        duration: Double,
        count: Int
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
        #expect(log.calls.contains(.mix(duration: Double(count) / fps)))
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
        #expect(log.calls.contains(.checkPlan(MixPlan(segments: []))))
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

    @Test("a PNG is the frame at `--at`, 0 when it is left out, checked and written once", arguments: [
        (nil as Double?, 0),
        (1.25, 2),
        (1.99, 3)
    ])
    func rendersFrameToPNG(
        time: Double?,
        frame: Int
    ) throws {
        // Given
        let log = RoleCallLog()
        let sut = pipeline(log: log)

        // When
        try sut.render(sequence(fps: 2, duration: 2), to: image, at: time, delivery: nil)

        // Then
        #expect(log.calls == [
            .checkMedia(path: "/abs/run.mp4"),
            .checkList(frame: frame),
            .draw(frame: frame),
            .writeImage(path: image, frame: frame)
        ])
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

    @Test("`--at` with a master, `--deliver` with a PNG, a delivery other than an MP4 and any other output stop", arguments: [
        ("/abs/out.mov", 0.5 as Double?, nil as String?, RenderError.timeOfMaster(path: "/abs/out.mov")),
        ("/abs/out.png", nil, "/abs/out.mp4", RenderError.deliveryOfStill(path: "/abs/out.mp4")),
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

    // MARK: - Private
    // The storyline entry's own sound and a sequence clip's music.
    private var soundtrack: [ResolvedSound] {
        [sound(video, place: "storyline[0]"), sound(music, place: "clips[0]")]
    }

    private func pipeline(
        log: RoleCallLog,
        refusal: RoleRefusal? = nil,
        hasher: any FileHashProvider = FileHashTable()
    ) -> RenderPipeline {
        RenderPipeline(
            decoder: RecordingDecoder(log: log, refuses: refusal == .decoder),
            renderer: RecordingRenderer(log: log, refuses: refusal == .renderer),
            mixer: RecordingMixer(log: log, refuses: refusal == .mixer),
            encoder: RecordingEncoder(log: log, refuses: refusal == .encoder),
            hasher: hasher
        )
    }

    // The checks of a two frame sequence of `video` and `music` rendered with a delivery: each media once, each frame,
    // the plan, and each target.
    private func checks(of sequence: ResolvedSequence) -> [RoleCall] {
        [
            .checkMedia(path: "/abs/run.mp4"),
            .checkMedia(path: "/abs/bgm.m4a"),
            .checkList(frame: 0),
            .checkList(frame: 1),
            .checkPlan(MixPlanner().mix(of: sequence)),
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
        audio: [ResolvedSound] = []
    ) -> ResolvedSequence {
        let entry = ResolvedStorylineClip(
            place: "storyline[0]",
            id: nil,
            media: .pinned(media ?? video),
            solid: nil,
            in: 0,
            out: duration,
            speed: 1,
            start: 0,
            end: duration,
            crop: [Keyframe(at: 0, value: Crop(whole))],
            track: nil,
            filter: [],
            transition: nil
        )

        return ResolvedSequence(
            format: ResolvedFormat(
                size: size,
                fps: fps,
                duration: duration,
                background: background,
                conform: .fit
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
            in: 0,
            origin: 0,
            out: 1,
            speed: 1,
            loop: false,
            start: 0,
            end: 1,
            audible: TimeRange(start: 0, end: 1),
            volume: [Keyframe(at: 0, value: 1)],
            fadeIn: nil,
            fadeOut: nil,
            incoming: nil,
            outgoing: nil
        )
    }
}
