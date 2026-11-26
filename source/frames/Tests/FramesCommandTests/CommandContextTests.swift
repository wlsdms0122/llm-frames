//
//  CommandContextTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import FramesTestMedia
import Testing

@testable import FramesCommand

// A context on the real roles with a shaping provider that finds no face.
@Suite("CommandContext Tests")
struct CommandContextTests {
    // MARK: - Property
    private let sut: CommandContext
    private let recorder = OutputRecorder()

    // MARK: - Initializer
    init() throws {
        let real = try RoleFactory().roles(for: .none)
        let roles = Roles(
            budget: real.budget,
            decoder: real.decoder,
            renderer: real.renderer,
            mixer: real.mixer,
            encoder: real.encoder,
            ocr: real.ocr,
            shaper: FacelessShaper(),
            tracker: real.tracker
        )
        sut = CommandContext(
            options: .none,
            roles: roles,
            output: recorder.output,
            environment: CommandEnvironment(
                variables: [:],
                executable: URL(fileURLWithPath: "/nonexistent/frames"),
                shippedPacks: URL(fileURLWithPath: "/nonexistent", isDirectory: true),
                standardInput: { Data() }
            )
        )
    }

    // MARK: - Test
    @Test("the label face stops when the shaping provider does not find the face time labels are set in")
    func refusesMissingLabelFace() throws {
        // When
        let error = #expect(throws: CommandError.self) {
            try sut.labelFace()
        }

        // Then
        #expect(
            error == .missingLabelFace(name: "HelveticaNeue-Medium", file: "/System/Library/Fonts/HelveticaNeue.ttc")
        )
        #expect(
            error?.description == #""/System/Library/Fonts/HelveticaNeue.ttc": the file has no face "HelveticaNeue-Medium", which time labels are set in"#
        )
    }

    @Test("extract writes frames when the shaping provider does not find the label face, since it draws no label")
    func extractsWithoutLabelFace() async throws {
        // Given
        let media = try TemporaryDirectory()
        let video = media.file("clip.mov")
        try await MovieWriter(size: Size(width: 64, height: 48), frameTimes: [0, 0.5], end: 1)
            .write(to: video) { canvas, _ in
                canvas.fill(red: 128, green: 128, blue: 128)
            }
        let directory = media.file("frames")
        let scanner = ArgumentScanner(
            command: "extract",
            rules: ExtractOptions.rules,
            positionals: ExtractOptions.positionals
        )
        let options = try ExtractOptions(try scanner.scan([video, directory, "--step", "0.5"]))

        // When
        try ExtractCommand().run(options, in: sut)

        // Then
        let names = try FileManager.default.contentsOfDirectory(atPath: directory).sorted()
        #expect(names == ["0000.png", "0001.png"])
        #expect(recorder.standardOutput.split(separator: "\n").count == 2)
    }

    // MARK: - Private
}
