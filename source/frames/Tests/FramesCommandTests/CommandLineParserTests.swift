//
//  CommandLineParserTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import FramesCommand

@Suite("CommandLineParser Tests")
struct CommandLineParserTests {
    // MARK: - Property
    private let sut = CommandLineParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "the global options come before the command, kept as written, and everything after its name is its own",
        arguments: [
            ([], Invocation.usage),
            (["--theme", "shorts/shorts"], .usage),
            (["--version"], .version),
            (["--decoder", "avfoundation", "--version"], .version),
            (["--help"], .help(options: .none)),
            (
                ["render", "/abs/doc.json", "-o", "/abs/out.mov"],
                .command(name: "render", arguments: ["/abs/doc.json", "-o", "/abs/out.mov"], options: .none)
            ),
            (
                ["--theme", "shorts/shorts", "--ocr", "vision", "timeline", "-", "--json"],
                .command(
                    name: "timeline",
                    arguments: ["-", "--json"],
                    options: GlobalOptions(
                        theme: "shorts/shorts",
                        decoder: nil,
                        renderer: nil,
                        mixer: nil,
                        encoder: nil,
                        ocr: "vision",
                        ocrLanguages: nil,
                        shaper: nil,
                        tracker: nil,
                        written: ["--theme", "shorts/shorts", "--ocr", "vision"]
                    )
                )
            ),
            (
                ["--tracker", "point", "autocut", "--tracker", "other"],
                .command(
                    name: "autocut",
                    arguments: ["--tracker", "other"],
                    options: GlobalOptions(
                        theme: nil,
                        decoder: nil,
                        renderer: nil,
                        mixer: nil,
                        encoder: nil,
                        ocr: nil,
                        ocrLanguages: nil,
                        shaper: nil,
                        tracker: "point",
                        written: ["--tracker", "point"]
                    )
                )
            )
        ]
    )
    func parsesCommandLine(
        arguments: [String],
        invocation: Invocation
    ) throws {
        // Given, When
        let parsed = try sut.parse(arguments)

        // Then
        #expect(parsed == invocation)
    }

    @Test(
        "an unknown global option, a missing value, a repeated option and arguments after --version or --help stop",
        arguments: [
            (
                ["--fps", "30", "render"],
                #"unknown option "--fps". Allowed: --theme, --decoder, --renderer, --mixer, --encoder, --shaper, --tracker, --ocr, --ocr-languages, --version, --help"#
            ),
            (
                ["--ocr-languages", "en_US", "probe"],
                #"--ocr-languages "en_US" is not BCP 47 tags separated by commas"#
            ),
            (["--theme"], "--theme takes a value, <pack/name | /abs/theme.json>"),
            (["--ocr", "vision", "--ocr", "vision", "probe"], "--ocr is given more than once"),
            (["--version", "now"], #"--version takes no arguments, found "now""#),
            (["--help", "render"], #"--help takes no arguments, found "render". A command's help is frames <command> --help"#)
        ]
    )
    func stopsOnBadCommandLine(
        arguments: [String],
        message: String
    ) {
        // Given, When, Then
        let error = #expect(throws: CommandError.self) { try sut.parse(arguments) }
        #expect(error?.description == message)
    }

    // MARK: - Private
}
