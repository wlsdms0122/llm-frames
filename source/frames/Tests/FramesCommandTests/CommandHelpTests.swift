//
//  CommandHelpTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/19/26.
//

import Frames
import Testing

@testable import FramesCommand

@Suite("CommandHelp Tests")
struct CommandHelpTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a command's help is its line of the usage, what it does, and each argument and option with what it takes")
    func writesHelp() {
        // Given
        let sut = CommandHelp(ProbeCommand())

        // When
        let text = sut.text

        // Then
        #expect(text == """
            frames probe <media> [--json]

            \(ProbeCommand().summary)

              <media>  \(ProbeOptions.positionals[0].help)
              --json   \(OptionRule.json.help)

            """)
    }

    @Test("a command without arguments or options has no list in its help")
    func writesHelpWithoutRows() {
        // Given
        let sut = CommandHelp(ThemeCommand())

        // When
        let text = sut.text

        // Then
        #expect(text == "frames theme\n\n\(ThemeCommand().summary)\n")
    }

    @Test(
        "a command's synopsis names each of its options and positional arguments",
        arguments: CommandTable.commands.map(\.name)
    )
    func namesEveryArgument(name: String) throws {
        // Given
        let command = try #require(CommandTable.commands.first { $0.name == name })

        // When
        let terms = terms(of: command)

        // Then
        for term in terms {
            #expect(command.synopsis.contains(term), "\(name) synopsis misses \(term)")
        }
    }

    @Test("the defaults help names are the ones the options take")
    func namesDefaults() throws {
        // Given
        let extract = ScannedArguments(
            command: "extract",
            placeholders: ExtractOptions.positionals.map(\.placeholder),
            rules: ExtractOptions.rules,
            positionals: ["/abs/in.mov", "/abs/out"],
            values: [:],
            flags: []
        )
        let transcode = ScannedArguments(
            command: "transcode",
            placeholders: TranscodeOptions.positionals.map(\.placeholder),
            rules: TranscodeOptions.rules,
            positionals: ["/abs/in.mov"],
            values: ["-o": "/abs/out.mp4"],
            flags: []
        )

        // When
        let range = try ExtractOptions(extract).range
        let quality = try TranscodeOptions(transcode).request.quality

        // Then
        #expect(range == FrameRange(from: nil, to: nil, step: 1))
        #expect(OptionRule.step.help.hasSuffix("Default: 1."))
        #expect(OptionRule.from.help.hasSuffix("Default: 0."))
        #expect(quality == .medium)
        #expect(TranscodeOptions.rules.contains { $0.name == "--quality" && $0.help.hasSuffix("Default: medium.") })
        #expect(SheetOptions.rules.contains { $0.name == "--cols" && $0.help.hasSuffix("Default: 6.") })
        #expect(CommandLineParser.rules.contains { $0.name == "--renderer" && $0.help.hasSuffix("Default: quartz.") })
    }

    // MARK: - Private
    private func terms<Described: Command>(of command: Described) -> [String] {
        Described.Options.positionals.map(\.placeholder) + Described.Options.rules.map(\.name)
    }
}
