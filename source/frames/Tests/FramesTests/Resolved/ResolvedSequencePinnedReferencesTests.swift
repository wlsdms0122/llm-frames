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
    @Test("a sequence lists its media, LUTs, transition media, fonts and sounds, each at the entry that names it")
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
                entry("storyline[0]", media: .pinned(video), filter: [.lut(file: lut, amount: 1)]),
                entry("storyline[1]", media: .pinned(frames), transition: transition())
            ],
            clips: [
                clip("clips[0]", content: .title(text())),
                clip("clips[1]", content: .media(ResolvedMediaClip(
                    media: .nested(nested),
                    timing: nil,
                    filter: [],
                    appearance: ResolvedMediaAppearance(conform: .fit, radius: 0, border: nil, shadow: nil)
                )))
            ],
            audio: [sound("clips[2]", media: music)]
        )

        // When
        let references = sut.pinnedReferences

        // Then
        #expect(references == [
            .media(video, place: "storyline[0]"),
            .file(lut, place: "storyline[0]"),
            .media(frames, place: "storyline[1]"),
            .media(stinger, place: "storyline[1]"),
            .media(wipe, place: "storyline[1]"),
            .file(font, place: "clips[0]"),
            .media(card, place: "clips[1].media.storyline[0]"),
            .file(font, place: "clips[1].media.clips[0]"),
            .media(music, place: "clips[2]")
        ])
    }

    @Test("an image sequence pins each of its frame files in frame order")
    func listsImageSequenceFiles() {
        // Given
        let sut = PinnedReference.media(frames, place: "storyline[0]")

        // When
        let files = sut.files

        // Then
        #expect(files == [pinned("/abs/frames/1.png"), pinned("/abs/frames/2.png")])
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
        filter: [ResolvedFilterOperation] = [],
        transition: ResolvedTransition? = nil
    ) -> ResolvedStorylineClip {
        ResolvedStorylineClip(
            place: place,
            id: nil,
            media: media,
            solid: nil,
            in: 0,
            out: 1,
            speed: 1,
            start: 0,
            end: 1,
            crop: [Keyframe(at: 0, value: Crop(whole))],
            track: nil,
            filter: filter,
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
                media: ResolvedTransitionMedia(media: wipe, duration: 0),
                softness: 0,
                isInverted: false,
                ease: .linear
            )
        )
    }

    private func clip(
        _ place: String,
        content: ResolvedClipContent
    ) -> ResolvedClip {
        ResolvedClip(
            place: place,
            id: nil,
            content: content,
            start: 0,
            end: 2,
            lane: 1,
            storyline: nil,
            parent: nil,
            box: nil,
            crop: nil,
            mask: nil,
            trackMatte: nil,
            track: nil,
            opacity: [Keyframe(at: 0, value: 1)],
            scale: nil,
            rotation: nil,
            blend: "normal",
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
            fadeIn: nil,
            fadeOut: nil,
            incoming: nil,
            outgoing: nil
        )
    }

    private func text() -> ResolvedText {
        let run = ResolvedGlyphRun(
            font: font,
            face: "Font-Bold",
            size: 20,
            color: Color(written: "#FFFFFF"),
            glyphs: [PositionedGlyph(id: 1, x: 0, y: 16)]
        )

        return ResolvedText(size: size, lineCount: 1, background: nil, stroke: nil, runs: [run])
    }
}
