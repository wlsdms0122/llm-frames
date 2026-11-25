//
//  ResolvedSequencePinnedReferencesTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("ResolvedSequence PinnedReferences Tests")
struct ResolvedSequencePinnedReferencesTests {
    // MARK: - Property
    private let whole = Rectangle(x: 0, y: 0, width: 40, height: 30)
    private let size = Size(width: 40, height: 30)
    private let video = Self.media("/abs/run.mp4")
    private let lut = Self.pinned("/abs/look.cube")
    private let map = Self.pinned("/abs/ripple.png")
    private let stinger = Self.media("/abs/stinger.mov")
    private let wipe = Self.media("/abs/wipe.png")
    private let font = Self.pinned("/abs/font.ttf")
    private let card = Self.media("/abs/card.png")
    private let music = Self.media("/abs/bgm.m4a")
    private let frames = PinnedMedia(
        source: .imageSequence([Self.pinned("/abs/frames/1.png"), Self.pinned("/abs/frames/2.png")]),
        frameTimes: [0, 0.5]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sequence lists its media in their written colour spaces, LUTs, displacement maps read as their tags say, fonts and sounds, each where it is named")
    func listsSequenceReferences() {
        // Given
        let nested = ResolvedSequence(
            format: format(),
            storyline: [entry("clips[1].media.storyline[0]", media: .pinned(card))],
            clips: [clip("clips[1].media.clips[0]", content: .title(text()))],
            audio: []
        )
        let sut = ResolvedSequence(
            format: format(),
            storyline: [
                entry("storyline[0]", media: .pinned(video), colorSpace: .rec709, filter: [
                    .lut(file: lut, amount: 1),
                    .displace(file: map, amount: 8, offset: Point(x: 0, y: 0))
                ]),
                entry("storyline[1]", media: .pinned(frames), transition: transition())
            ],
            clips: [
                clip("clips[0]", content: .title(text())),
                clip("clips[1]", content: .media(ResolvedMediaClip(
                    media: .nested(nested),
                    timing: nil,
                    filter: .off,
                    appearance: ResolvedMediaAppearance(conform: .fit, radius: .off, border: .off, shadow: .off)
                )))
            ],
            audio: [sound("clips[2]", media: music)]
        )

        // When
        let references = sut.pinnedReferences

        // Then
        #expect(references == [
            .media(video, place: "storyline[0]", colorSpace: .rec709),
            .file(lut, place: "storyline[0]"),
            .media(PinnedMedia(source: .file(map)), place: "storyline[0]", colorSpace: nil),
            .media(frames, place: "storyline[1]", colorSpace: nil),
            .media(stinger, place: "storyline[1]", colorSpace: nil),
            .media(wipe, place: "storyline[1]", colorSpace: .displayP3),
            .file(font, place: "clips[0]"),
            .media(card, place: "clips[1].media.storyline[0]", colorSpace: nil),
            .file(font, place: "clips[1].media.clips[0]"),
            .sound(music, place: "clips[2]")
        ])
    }

    @Test("an image sequence pins each of its frame files in frame order")
    func listsImageSequenceFiles() {
        // Given
        let sut = PinnedReference.media(frames, place: "storyline[0]", colorSpace: nil)

        // When
        let files = sut.files

        // Then
        #expect(files == [pinned("/abs/frames/1.png"), pinned("/abs/frames/2.png")])
    }

    @Test("each impulse response is pinned with its hash as a sound, where its clip, its compound clip or the sequence names it")
    func listsImpulseResponses() throws {
        // Given
        let plan = try Fixture.documentPlanner.plan(Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "kind": "convolve", "file": "/abs/ding.wav" } },
                         { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 2 } ],
                                      "audioFilter": { "kind": "convolve", "file": "/abs/bgm.m4a" } },
                           "picture": false, "audioFilter": [ { "kind": "gate", "threshold": -50 }, { "kind": "convolve", "file": "/abs/run.mp4" } ] } ],
              "audioFilter": { "kind": "convolve", "file": "/abs/ding.wav", "gain": -3 } }
            """#))
        let sut = try ResolvedSequence(plan: plan, hashes: FileHashTable(["/abs/ding.wav": "ding-digest"]))

        // When
        let references = sut.pinnedReferences

        // Then
        let sounds = references.compactMap { reference -> String? in
            guard case .sound = reference, let file = reference.files.first else { return nil }

            return "\(reference.place): \(file.path) \(file.sha256)"
        }
        #expect(sounds == [
            "storyline[0]: /abs/run.mp4 sha256-of-/abs/run.mp4",
            "clips[0]: /abs/bgm.m4a sha256-of-/abs/bgm.m4a",
            "clips[0]: /abs/ding.wav ding-digest",
            "clips[1].media.storyline[0]: /abs/run.mp4 sha256-of-/abs/run.mp4",
            "clips[1]: /abs/bgm.m4a sha256-of-/abs/bgm.m4a",
            "clips[1]: /abs/run.mp4 sha256-of-/abs/run.mp4",
            "audioFilter: /abs/ding.wav ding-digest"
        ])
        #expect(references.filter { $0.files.map(\.path) == ["/abs/ding.wav"] }.allSatisfy { reference in
            if case .sound = reference { true } else { false }
        })
    }

    // MARK: - Private
    private static func pinned(_ path: String) -> PinnedFile {
        PinnedFile(path: path, sha256: String(repeating: "0", count: 64))
    }

    private static func media(_ path: String) -> PinnedMedia {
        PinnedMedia(source: .file(pinned(path)))
    }

    private func pinned(_ path: String) -> PinnedFile {
        Self.pinned(path)
    }

    private func format() -> ResolvedFormat {
        ResolvedFormat(
            size: size,
            fps: 10,
            duration: 2,
            background: Color(written: "#000000"),
            conform: .fit
        )
    }

    private func entry(
        _ place: String,
        media: ResolvedMediaContent,
        colorSpace: ColorSpace? = nil,
        filter: [ResolvedFilterOperation] = [],
        transition: ResolvedTransition? = nil
    ) -> ResolvedStorylineClip {
        ResolvedStorylineClip(
            place: place,
            id: nil,
            media: media,
            color: nil,
            colorSpace: colorSpace,
            in: 0,
            out: 1,
            speed: 1,
            start: 0,
            end: 1,
            crop: .keyframes([Keyframe(at: 0, value: Crop(whole))]),
            track: nil,
            filter: .filter(filter),
            transition: transition,
            filling: size
        )
    }

    private func transition() -> ResolvedTransition {
        let span = Span(ease: .linear, keys: [SpanKey(t: 0, values: [.opacity: 1])])

        return ResolvedTransition(
            start: 0.75,
            end: 1.25,
            over: .incoming,
            incoming: nil,
            outgoing: nil,
            cover: ResolvedCover(source: .media(ResolvedTransitionMedia(media: stinger, duration: 1)), span: span),
            matte: ResolvedMatte(
                media: ResolvedTransitionMedia(media: wipe, colorSpace: .displayP3, duration: 0),
                softness: 0,
                isInverted: false,
                ease: .linear
            )
        )
    }

    private func clip(
        _ place: String,
        content: ResolvedPicture
    ) -> ResolvedClip {
        ResolvedClip(
            place: place,
            id: nil,
            content: .picture(
                content,
                ResolvedComposite(lane: 1, opacity: [Keyframe(at: 0, value: 1)], blend: "normal")
            ),
            start: 0,
            end: 2,
            storyline: nil,
            parent: nil,
            box: nil,
            crop: nil,
            mask: nil,
            trackMatte: nil,
            track: nil,
            scale: nil,
            rotation: nil,
            animation: .none
        )
    }

    private func sound(
        _ place: String,
        media: PinnedMedia
    ) -> ResolvedSound {
        ResolvedSound(
            place: place,
            media: media,
            nested: [],
            played: PlayedRange(
                map: TimeMap(origin: 0, in: 0, speed: 1),
                out: 2,
                loop: false
            ),
            start: 0,
            end: 2,
            audible: TimeRange(start: 0, end: 2),
            volume: [Keyframe(at: 0, value: 1)],
            pan: [Keyframe(at: 0, value: 0)],
            fadeIn: nil,
            fadeOut: nil,
            incoming: nil,
            outgoing: nil
        )
    }

    private func text() -> ResolvedText {
        let run = ResolvedGlyphRun(
            source: 0,
            font: font,
            face: "Font-Bold",
            size: 20,
            color: .track([Keyframe(at: 0, value: .color(Color(written: "#FFFFFF")))]),
            stroke: .off,
            baselineShift: .off,
            isSideways: false,
            horizontalScale: 1,
            staticTracking: 0,
            tracking: .off,
            highlight: nil,
            underline: nil,
            glyphs: [PositionedGlyph(id: 1, x: 0, y: 16)]
        )

        return ResolvedText(size: size, background: nil, runs: [run])
    }
}
