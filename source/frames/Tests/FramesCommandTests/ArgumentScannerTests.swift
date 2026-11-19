//
//  ArgumentScannerTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import FramesCommand

@Suite("ArgumentScanner Tests")
struct ArgumentScannerTests {
    // MARK: - Property
    private let sut = ArgumentScanner(command: "render", rules: RenderOptions.rules, positionals: RenderOptions.positionals)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "positional arguments, option values and flags are told apart in any order, and - is a positional argument",
        arguments: [
            (["/abs/doc.json", "-o", "/abs/out.mov"], "/abs/doc.json", "/abs/out.mov", nil),
            (["-o", "/abs/out.mov", "-", "--deliver", "/abs/out.mp4"], "-", "/abs/out.mov", "/abs/out.mp4")
        ]
    )
    func scansArguments(
        arguments: [String],
        document: String,
        output: String,
        delivery: String?
    ) throws {
        // Given, When
        let options = try RenderOptions(sut.scan(arguments))

        // Then
        #expect(options.document == document)
        #expect(options.output == output)
        #expect(options.delivery == delivery)
        #expect(options.arguments == nil)
    }

    @Test("a flag is set only when it is given")
    func scansFlag() throws {
        // Given
        let sut = ArgumentScanner(command: "timeline", rules: TimelineOptions.rules, positionals: TimelineOptions.positionals)

        // When
        let machine = try TimelineOptions(sut.scan(["/abs/doc.json", "--json"]))
        let text = try TimelineOptions(sut.scan(["/abs/doc.json"]))

        // Then
        #expect(machine.isMachineOutput)
        #expect(!text.isMachineOutput)
    }

    @Test(
        "an unknown option, a missing value, a repeated option, an extra argument and a relative path stop, naming the command",
        arguments: [
            (["/abs/doc.json", "--fps", "30"], #"render: unknown option "--fps". Allowed: -o, --at, --deliver, --args"#),
            (["/abs/doc.json", "-o"], "render: -o takes a value, <out.mov | out.png>"),
            (["/abs/doc.json", "-o", "/abs/a.mov", "-o", "/abs/b.mov"], "render: -o is given more than once"),
            (["/abs/doc.json", "/abs/other.json", "-o", "/abs/a.mov"], #"render: unexpected argument "/abs/other.json""#),
            (["/abs/doc.json"], "render: missing -o <out.mov | out.png>"),
            (["-o", "/abs/a.mov"], "render: missing <document.json>"),
            (["/abs/doc.json", "-o", "out.mov"], #"render: -o "out.mov" is not an absolute path, and paths are absolute"#),
            (
                ["/abs/doc.json", "-o", "/abs/a.mov", "--deliver", "out.mp4"],
                #"render: --deliver "out.mp4" is not an absolute path, and paths are absolute"#
            ),
            (
                ["/abs/doc.json", "-o", "/abs/a.mov", "--args", "args.json"],
                #"render: --args "args.json" is not an absolute path, and paths are absolute"#
            )
        ]
    )
    func stopsOnBadArguments(
        arguments: [String],
        message: String
    ) {
        // Given, When, Then
        let error = #expect(throws: CommandError.self) { try RenderOptions(sut.scan(arguments)) }
        #expect(error?.description == message)
    }

    @Test("a command that takes no options says so when it is given one")
    func stopsOnOptionOfCommandWithoutOptions() {
        // Given
        let sut = ArgumentScanner(command: "theme", rules: ThemeOptions.rules, positionals: ThemeOptions.positionals)

        // When, Then
        let error = #expect(throws: CommandError.self) { try sut.scan(["--json"]) }
        #expect(error?.description == #"theme: unknown option "--json". It takes no options"#)
    }

    // MARK: - Private
}
