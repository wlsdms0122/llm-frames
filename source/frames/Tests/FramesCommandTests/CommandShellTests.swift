//
//  CommandShellTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import Testing

@testable import FramesCommand

@Suite("CommandShell Tests")
struct CommandShellTests {
    // MARK: - Property
    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
    }

    // MARK: - Test
    @Test("--version prints the version alone and exits with 0")
    func printsVersion() {
        // Given, When
        let code = sut.run(["--version"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == "1.0.0\n")
        #expect(sut.standardError.isEmpty)
    }

    @Test("without arguments frames prints usage on standard error and exits with 64, and so it does with no command")
    func printsUsage() {
        // Given, When
        let optionsOnly = sut.run(["--theme", "shorts/shorts"])
        let code = sut.run([])

        // Then
        #expect(code == 64)
        #expect(optionsOnly == 64)
        #expect(sut.standardOutput.isEmpty)
        #expect(sut.standardError == CommandUsage.text)
        #expect(sut.standardError.hasPrefix("frames [--theme <pack/name | /abs/theme.json>] [--decoder <name>]"))
        #expect(sut.standardError.contains("\ntimeline  <document.json> [--args <args.json>] [--json]\n"))
    }

    @Test(
        "what stops prints frames: and the reason on standard error and exits with 1",
        arguments: [
            (["resolve", "/abs/doc.json"], "resolve: missing -o <resolved.json>"),
            (["timeline", "--json"], "timeline: missing <document.json>"),
            (["timeline", "/abs/doc.json", "--fps", "30"], #"timeline: unknown option "--fps". Allowed: --args, --json"#),
            (["timeline", "/abs/doc.json", "--args"], "timeline: --args takes a value, <args.json>"),
            (
                ["timeline", "doc.json"],
                #"timeline: the document "doc.json" is not an absolute path, <pack>/<name> or -, and paths are absolute"#
            ),
            (["timeline", "a/b/c.json"], #"timeline: the document "a/b/c.json" is not an absolute path, <pack>/<name> or -, and paths are absolute"#),
            (["timeline", "/nowhere/doc.json"], "/nowhere/doc.json: the file is not there"),
            (["timeline", "nopack/intro"], #"timeline: unknown template "nopack/intro""#),
            (["--decoder", "ffmpeg", "theme"], #"--decoder: unknown decoder "ffmpeg". Known: avfoundation"#),
            (["--renderer", "metal", "theme"], #"--renderer: unknown renderer "metal". Known: quartz"#),
            (["--ocr", "tesseract", "theme"], #"--ocr: unknown OCR provider "tesseract". Known: vision"#),
            (["--shaper", "harfbuzz", "theme"], #"--shaper: unknown shaping provider "harfbuzz". Known: coretext"#),
            (["--tracker", "klt", "theme"], #"--tracker: unknown tracker provider "klt". Known: point"#),
            (["--mixer", "core", "theme"], #"--mixer: unknown mixer "core". Known: avfoundation"#),
            (["--encoder", "ffmpeg", "theme"], #"--encoder: unknown encoder "ffmpeg". Known: avfoundation"#),
            (["theme", "base"], #"theme: unexpected argument "base""#),
            (["frames-nowhere"], #"unknown command "frames-nowhere""#)
        ]
    )
    func stops(
        arguments: [String],
        message: String
    ) {
        // Given, When
        let code = sut.run(arguments)

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: \(message)\n")
        #expect(sut.standardOutput.isEmpty)
    }

    @Test("a resolved document has its theme and arguments written in, so --theme or --args with it stops")
    func stopsOnOptionsWithResolvedDocument() throws {
        // Given
        let document = try sut.write(#"{ "kind": "image", "resolved": "1.0.0" }"#, named: "resolved.json")
        let arguments = try sut.write("{}", named: "args.json")

        // When
        let themed = sut.run(["--theme", "shorts/shorts", "timeline", document])
        let themedError = sut.standardError
        let argued = sut.run(["timeline", document, "--args", arguments])

        // Then
        #expect(themed == 1)
        #expect(argued == 1)
        #expect(themedError == "frames: top level (image): a resolved document has its theme and arguments written in, so it takes no --theme\n")
        #expect(sut.standardError == "frames: top level (image): a resolved document has its theme and arguments written in, so it takes no --args\n")
    }

    @Test("a document that is not a template takes no --args, and a template takes no --theme")
    func stopsOnArgumentsAndThemeMismatch() throws {
        // Given
        let document = try sut.write(##"{ "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 1 } ] }"##, named: "doc.json")
        let template = try sut.write(##"{ "kind": "sequence", "params": {}, "storyline": [ { "solid": "#000000", "duration": 1 } ] }"##, named: "template.json")
        let arguments = try sut.write("{}", named: "args.json")

        // When
        let argued = sut.run(["timeline", document, "--args", arguments])
        let arguedError = sut.standardError
        let themed = sut.run(["--theme", "/abs/theme.json", "timeline", template])

        // Then
        #expect(argued == 1)
        #expect(themed == 1)
        #expect(arguedError == "frames: top level (sequence): the document declares no params, so it takes no arguments\n")
        #expect(sut.standardError == "frames: top level (sequence): a template resolves on the base theme and its own theme, so it takes no --theme\n")
    }

    @Test("a command frames does not have runs frames-<name> from PATH with the global options and its arguments, and exits with its code")
    func runsExtension() throws {
        // Given
        let bin = URL(fileURLWithPath: sut.directory.file("bin"), isDirectory: true)
        let record = sut.directory.file("argv.txt")
        let script = try sut.write(
            """
            #!/bin/sh
            printf '%s\\n' "$0" "$@" > "$FRAMES_TEST_ARGV"
            exit 3
            """,
            to: bin.appendingPathComponent("frames-autocut")
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        // When
        let code = sut.run(
            ["--theme", "shorts/shorts", "autocut", "/abs/doc.json", "--gap", "0.5", "-"],
            variables: ["PATH": "\(bin.path):/usr/bin:/bin", "FRAMES_TEST_ARGV": record]
        )

        // Then
        let argv = try String(contentsOfFile: record, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(code == 3)
        #expect(argv == [script.path, "--theme", "shorts/shorts", "/abs/doc.json", "--gap", "0.5", "-"])
        #expect(sut.standardError.isEmpty)
    }

    @Test("a frames-<name> that is not executable or not on PATH is no extension")
    func ignoresUnexecutableExtension() throws {
        // Given
        let bin = URL(fileURLWithPath: sut.directory.file("bin"), isDirectory: true)
        try sut.write("#!/bin/sh\nexit 0\n", to: bin.appendingPathComponent("frames-autocut"))

        // When
        let code = sut.run(["autocut"], variables: ["PATH": bin.path])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: unknown command \"autocut\"\n")
    }

    @Test("a mistyped role name stops before an extension runs")
    func checksRolesBeforeExtension() throws {
        // Given
        let bin = URL(fileURLWithPath: sut.directory.file("bin"), isDirectory: true)
        let script = try sut.write("#!/bin/sh\nexit 0\n", to: bin.appendingPathComponent("frames-autocut"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        // When
        let code = sut.run(["--decoder", "ffmpeg", "autocut"], variables: ["PATH": bin.path])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: --decoder: unknown decoder \"ffmpeg\". Known: avfoundation\n")
    }

    @Test("theme prints the base theme as it is written")
    func printsTheme() {
        // Given, When
        let code = sut.run(["theme"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == BaseTheme.text + "\n")
    }

    // MARK: - Private
}
