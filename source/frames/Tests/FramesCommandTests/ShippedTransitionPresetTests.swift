//
//  ShippedTransitionPresetTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames
@testable import FramesCommand

@Suite("ShippedTransitionPreset Tests")
struct ShippedTransitionPresetTests {
    // MARK: - Property
    private static let seconds: [String: Double] = [
        "fade": 0.4,
        "dip-black": 0.7,
        "flash": 0.3,
        "push-left": 0.45,
        "push-up": 0.45,
        "slide-left": 0.45,
        "slide-right": 0.45,
        "slide-up": 0.45,
        "uncover-left": 0.45,
        "wipe-left": 0.5,
        "wipe-right": 0.5,
        "wipe-down": 0.5,
        "zoom-in": 0.4,
        "zoom-out": 0.4
    ]
    private static let names = seconds.keys.sorted()
    private static let progresses = (0...100).map { Double($0) / 100 }

    private let sut: PresetLibrary
    private let installed: TemporaryDirectory
    private let sampler = TransitionSampler()
    private let frame = Rectangle(x: 0, y: 0, width: 1920, height: 1080)

    // MARK: - Initializer
    init() throws {
        let environment = CommandEnvironment.current
        installed = try TemporaryDirectory()
        sut = PresetLibrary(
            packs: PackLibrary(
                installed: URL(fileURLWithPath: installed.path, isDirectory: true),
                shipped: environment.shippedPacks
            )
        )
    }

    // MARK: - Test
    @Test("the shipped transitions are exactly the fourteen of the frames pack, each read without error")
    func shipsNames() throws {
        // Given, When
        let names = try sut.presets(of: .transition).map(\.name)

        // Then
        #expect(names.sorted() == Self.names.map { "frames/\($0)" })
    }

    @Test("every shipped transition is as long as its table says", arguments: names)
    func lastsSeconds(name: String) throws {
        // Given, When
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))

        // Then
        #expect(preset.seconds == Self.seconds[name])
        #expect(!preset.description.isEmpty)
    }

    @Test("every shipped transition but fade, dip-black and flash eases in and out, and those three run at an even rate", arguments: names)
    func easesAsTableSays(name: String) throws {
        // Given
        let even = ["fade", "dip-black", "flash"]

        // When
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))
        let eases = [preset.incoming, preset.outgoing, preset.cover?.span].compactMap { $0?.ease }

        // Then
        #expect(!eases.isEmpty)
        #expect(eases.allSatisfy { $0 == (even.contains(name) ? .linear : .easeInOut) })
    }

    @Test("every shipped transition's description is one capitalised sentence", arguments: names)
    func describesInOneSentence(name: String) throws {
        // Given, When
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))

        // Then
        #expect(preset.description.first?.isUppercase == true)
        #expect(preset.description.hasSuffix("."))
        #expect(!preset.description.dropLast().contains(". "))
    }

    @Test("every shipped transition crossfades the sound at constant power", arguments: names)
    func crossfadesAtConstantPower(name: String) throws {
        // Given, When
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))

        // Then
        #expect(preset.audio == .constantPower)
    }

    @Test("at its end a shipped transition shows the incoming clip whole and in place, with no cover", arguments: names)
    func endsOnIncoming(name: String) throws {
        // Given
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))

        // When
        let incoming = picture(moving: preset.incoming, at: 1)
        let outgoing = picture(moving: preset.outgoing, at: 1)

        // Then
        #expect(isStill(incoming))
        #expect(coverOpacity(of: preset, at: 1) == 0)
        if preset.over == .outgoing {
            #expect(!covers(outgoing))
        }
    }

    @Test("at its start a shipped transition shows only the outgoing clip, whole and in place", arguments: names)
    func startsOnOutgoing(name: String) throws {
        // Given
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))

        // When
        let incoming = picture(moving: preset.incoming, at: 0)
        let outgoing = picture(moving: preset.outgoing, at: 0)

        // Then
        #expect(isStill(outgoing))
        #expect(coverOpacity(of: preset, at: 0) == 0)
        if preset.over == .incoming {
            #expect(!covers(incoming))
        }
    }

    @Test("a shipped cover is fully opaque whenever the incoming clip switches on, so the scene change is hidden", arguments: ["dip-black", "flash"])
    func hidesSceneChange(name: String) throws {
        // Given
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))

        // When
        let changes = zip(Self.progresses, Self.progresses.dropFirst()).filter { before, after in
            picture(moving: preset.incoming, at: before).opacity
                != picture(moving: preset.incoming, at: after).opacity
        }

        // Then
        #expect(!changes.isEmpty)
        for (before, after) in changes {
            #expect(coverOpacity(of: preset, at: before) == 1)
            #expect(coverOpacity(of: preset, at: after) == 1)
        }
    }

    @Test(
        "a push moves both clips as one strip, one frame apart in the direction it pushes",
        arguments: [("push-left", MotionProperty.x), ("push-up", MotionProperty.y)]
    )
    func pushesStrip(
        name: String,
        property: MotionProperty
    ) throws {
        // Given
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))
        let incoming = try #require(preset.incoming)
        let outgoing = try #require(preset.outgoing)
        let evaluator = SpanEvaluator()

        // When
        let gaps = Self.progresses.map { progress in
            evaluator.motion(of: incoming, at: progress).value(of: property)
                - evaluator.motion(of: outgoing, at: progress).value(of: property)
        }

        // Then
        #expect(gaps.allSatisfy { abs($0 - 1) < 1e-9 })
    }

    @Test(
        "a slide or uncover moves only the clip on top, from or to the side its name says",
        arguments: [
            ("slide-left", MotionProperty.x, 1.0),
            ("slide-right", MotionProperty.x, -1.0),
            ("slide-up", MotionProperty.y, 1.0),
            ("uncover-left", MotionProperty.x, -1.0)
        ]
    )
    func movesTop(
        name: String,
        property: MotionProperty,
        offset: Double
    ) throws {
        // Given
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))
        let moving = try #require(preset.over == .incoming ? preset.incoming : preset.outgoing)
        let still = preset.over == .incoming ? preset.outgoing : preset.incoming
        let evaluator = SpanEvaluator()

        // When
        let farthest = evaluator.motion(of: moving, at: preset.over == .incoming ? 0 : 1).value(of: property)

        // Then
        #expect(farthest == offset)
        #expect(still == nil)
    }

    @Test(
        "a wipe reveals the incoming clip from the side opposite its direction",
        arguments: [("wipe-left", RevealEdge.right), ("wipe-right", RevealEdge.left), ("wipe-down", RevealEdge.top)]
    )
    func wipesFromSide(
        name: String,
        side: RevealEdge
    ) throws {
        // Given
        let preset = try #require(try sut.transition(PresetInstance(name: "frames/\(name)")))

        // When
        let incoming = try #require(preset.incoming)

        // Then
        #expect(incoming.revealFrom == side)
        #expect(preset.outgoing == nil)
    }

    // MARK: - Private
    private func coverOpacity(
        of preset: TransitionPreset,
        at progress: Double
    ) -> Double {
        preset.cover.map { sampler.coverOpacity(of: $0.span, at: SampleProgress(progress)) } ?? 0
    }

    // What a storyline picture's outer item takes from a span at a progress: its transform about the centre of the
    // frame, its opacity and its reveal of the frame. A side the preset gives no span stays still and whole.
    private func picture(
        moving span: Span?,
        at progress: Double
    ) -> (transform: Frames.AffineTransform, opacity: Double, reveal: Rectangle?) {
        let sample = span.map { span in
            MotionSample(motion: SpanEvaluator().motion(of: span, at: progress), revealFrom: span.revealFrom)
        } ?? .none
        let presentation = ItemPresentation(area: frame, opacity: 1, motion: sample.motion)
        let reveal = sample.reveal.rectangle(wiping: frame, from: sample.revealFrom)

        return (presentation.transform, presentation.opacity, reveal)
    }

    private func isStill(_ picture: (transform: Frames.AffineTransform, opacity: Double, reveal: Rectangle?)) -> Bool {
        picture.transform == .identity && picture.opacity == 1 && picture.reveal == nil
    }

    // Whether a storyline picture shows anything over the frame: some opacity, some reveal, and its moved rect
    // overlapping.
    private func covers(_ picture: (transform: Frames.AffineTransform, opacity: Double, reveal: Rectangle?)) -> Bool {
        guard picture.opacity > 0 else { return false }
        if let reveal = picture.reveal, reveal.width <= 0 || reveal.height <= 0 {
            return false
        }

        let corners = picture.transform.apply(toCornersOf: frame)
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        let overlapsWidth = min(xs.max() ?? 0, frame.x + frame.width) - max(xs.min() ?? 0, frame.x)
        let overlapsHeight = min(ys.max() ?? 0, frame.y + frame.height) - max(ys.min() ?? 0, frame.y)
        return overlapsWidth > 1e-9 && overlapsHeight > 1e-9
    }
}
