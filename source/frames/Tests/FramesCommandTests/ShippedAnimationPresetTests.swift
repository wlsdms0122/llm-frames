//
//  ShippedAnimationPresetTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames
@testable import FramesCommand

// The animation presets frames ships, read from the tool's own resource bundle as the tool reads them, with no pack
// installed beside them.
@Suite("ShippedAnimationPreset Tests")
struct ShippedAnimationPresetTests {
    // MARK: - Property
    private static let names = [
        "none", "fade", "pop", "stamp", "zoom", "draw", "wipe",
        "rise", "drop", "slide-left", "bounce", "pulse", "blink", "shake"
    ]

    private let directory: TemporaryDirectory
    private let shipped = CommandEnvironment.current.shippedPacks
    private let sut: PresetLibrary
    private let evaluator = SpanEvaluator()

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
        sut = PresetLibrary(
            packs: PackLibrary(
                installed: URL(fileURLWithPath: directory.file("installed"), isDirectory: true),
                shipped: shipped
            )
        )
    }

    // MARK: - Test
    @Test("the shipped animations are exactly the 14 that FRAMES-16 names")
    func namesShippedAnimations() throws {
        // Given, When
        let names = try sut.presets(of: .animation).map(\.name)

        // Then
        #expect(names.sorted() == Self.names.map { "frames/\($0)" }.sorted())
    }

    @Test("every shipped animation reads and says in one line how it looks", arguments: names)
    func readsAnimation(name: String) throws {
        // Given, When
        let preset = try #require(try sut.animation(named: "frames/\(name)"))

        // Then
        #expect(!preset.description.isEmpty)
        #expect(!preset.description.contains("\n"))
    }

    @Test("none has no span, so a clip simply shows")
    func noneChangesNothing() throws {
        // Given, When
        let preset = try #require(try sut.animation(named: "frames/none"))

        // Then
        #expect(preset.entrance == nil)
        #expect(preset.loop == nil)
        #expect(preset.exit == nil)
    }

    @Test("only pulse, blink and shake loop, until the clip ends")
    func loopsOnlyWhereTheLookRepeats() throws {
        // Given, When
        let looping = try Self.names.filter { try sut.animation(named: "frames/\($0)")?.loop != nil }

        // Then
        #expect(looping == ["pulse", "blink", "shake"])
    }

    @Test("an entrance starts hidden and ends at the clip's own geometry", arguments: names)
    func entranceEndsInPlace(name: String) throws {
        // Given
        let preset = try #require(try sut.animation(named: "frames/\(name)"))
        guard let entrance = preset.entrance else { return }

        // When
        let start = evaluator.motion(of: entrance.span, at: 0)
        let end = evaluator.motion(of: entrance.span, at: 1)

        // Then
        #expect(isHidden(start))
        #expect(isInPlace(end))
    }

    @Test("an exit starts at the clip's own geometry and ends hidden", arguments: names)
    func exitEndsHidden(name: String) throws {
        // Given
        let preset = try #require(try sut.animation(named: "frames/\(name)"))
        guard let exit = preset.exit else { return }

        // When
        let start = evaluator.motion(of: exit.span, at: 0)
        let end = evaluator.motion(of: exit.span, at: 1)

        // Then
        #expect(isInPlace(start))
        #expect(isHidden(end))
    }

    @Test("a loop starts and ends at the clip's own geometry, so it joins the entrance and itself with no jump", arguments: names)
    func loopJoinsWithoutJump(name: String) throws {
        // Given
        let preset = try #require(try sut.animation(named: "frames/\(name)"))
        guard let loop = preset.loop else { return }

        // When
        let start = evaluator.motion(of: loop.span, at: 0)
        let end = evaluator.motion(of: loop.span, at: 1)

        // Then
        #expect(isInPlace(start))
        #expect(isInPlace(end))
    }

    @Test("pulse jabs an arrow forward with nudge and back while it pulses")
    func pulseJabsArrow() throws {
        // Given
        let preset = try #require(try sut.animation(named: "frames/pulse"))
        let loop = try #require(preset.loop)

        // When
        let nudges = stride(from: 0.0, through: 1, by: 0.05).map { evaluator.motion(of: loop.span, at: $0).value(of: .nudge) }

        // Then
        #expect(nudges.max() ?? 0 > 0)
        #expect(nudges.min() == 0)
    }

    @Test("a sequence with a box label resolves on the base theme alone, and the label pops in with the shipped pop")
    func resolvesLabelOnBaseTheme() throws {
        // Given
        let document = directory.file("label.json")
        let resolved = directory.file("label.resolved.json")
        try Data(labelSequence.utf8).write(to: URL(fileURLWithPath: document))
        let pop = try #require(try sut.animation(named: "frames/pop")?.entrance)
        let recorder = OutputRecorder()
        let environment = CommandEnvironment(
            variables: ["FRAMES_HOME": directory.file("home"), "PATH": "/usr/bin:/bin"],
            shippedPacks: shipped,
            standardInput: { Data() }
        )

        // When
        let code = CommandShell(environment: environment, output: recorder.output).run(["resolve", document, "-o", resolved])

        // Then
        #expect(recorder.standardError == "")
        #expect(code == 0)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: resolved))) as? [String: Any]
        let clip = (object?["clips"] as? [[String: Any]])?.first
        let animation = (clip?["label"] as? [String: Any])?["animation"] as? [String: Any]
        let entrance = animation?["entrance"] as? [String: Any]
        #expect(entrance?["seconds"] as? Double == pop.length)
        #expect(entrance?["ease"] as? String == "back-out")
    }

    // MARK: - Private
    private var labelSequence: String {
        #"""
        { "kind": "sequence", "format": { "size": [640, 360], "fps": 30 },
          "storyline": [
            { "solid": "#FFFFFF", "duration": 2,
              "connected": [ { "at": [0.5, 1.5], "shape": "box", "area": [100, 120, 200, 80], "label": "here" } ] }
          ] }
        """#
    }

    // Nothing of the clip shows: it is transparent or unrevealed, to within what an ease that starts at 0 rounds to.
    private func isHidden(_ motion: Motion) -> Bool {
        abs(motion.value(of: .opacity)) < 1e-9 || abs(motion.value(of: .reveal)) < 1e-9
    }

    // Every property at its default, so the clip stands exactly where its keyframes put it.
    private func isInPlace(_ motion: Motion) -> Bool {
        MotionProperty.allCases.allSatisfy { property in
            abs(motion.value(of: property) - property.defaultValue) < 1e-9
        }
    }
}
