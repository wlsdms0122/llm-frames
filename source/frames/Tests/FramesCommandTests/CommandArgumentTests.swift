//
//  CommandArgumentTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import FramesCommand

// Each command's arguments stop before anything is read or written, naming the command and the option.
@Suite("CommandArgument Tests")
struct CommandArgumentTests {
    // MARK: - Property
    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
    }

    // MARK: - Test
    @Test("a missing, relative, mistyped or conflicting argument stops with its reason", arguments: [
        (["still", "/abs/doc.json", "-o", "/abs/still.png"], "still: missing --at <t>[,<t>...]"),
        (
            ["still", "/abs/doc.json", "--at", "0.5,x", "-o", "/abs/still.png"],
            #"still: --at "0.5,x" is not seconds separated by commas"#
        ),
        (["still", "/abs/doc.json", "--at", "0.5", "-o", "still.png"], #"still: -o "still.png" is not an absolute path, and paths are absolute"#),
        (["sheet", "/abs/doc.json"], "sheet: missing -o <out.png>"),
        (["sheet", "/abs/clip.mov", "-o", "/abs/sheet.png", "--cols", "two"], #"sheet: --cols "two" is not a whole number"#),
        (["sheet", "/abs/clip.mov", "-o", "/abs/sheet.png", "--step", "inf"], #"sheet: --step "inf" is not a number of seconds"#),
        (["extract", "/abs/clip.mov"], "extract: missing <outdir>"),
        (["extract", "/abs/clip.mov", "frames"], #"extract: <outdir> "frames" is not an absolute path, and paths are absolute"#),
        (["probe"], "probe: missing <media>"),
        (["probe", "clip.mov"], #"probe: <media> "clip.mov" is not an absolute path, and paths are absolute"#),
        (["probe", "/abs/deck.pdf", "--page", "0"], #"probe: --page "0" is not a whole number from 1"#),
        (["ocr", "/abs/clip.mov", "--at", "1", "--from", "0"], "ocr: --at and --from are not given together"),
        (["ocr", "/abs/clip.mov", "--to", "1"], "ocr: missing --step <s>"),
        (["ocr", "/abs/deck.pdf", "--page", "1.5"], #"ocr: --page "1.5" is not a whole number from 1"#),
        (["track", "/abs/clip.mov", "--area", "[0, 0, 1, 1]"], "track: missing --at <t>"),
        (["track", "/abs/clip.mov", "--at", "0"], "track: missing --area <area> or --quad <quad>"),
        (
            ["track", "/abs/clip.mov", "--at", "0", "--area", "[0, 0, 1, 1]", "--quad", "[[0, 0], [1, 0], [1, 1], [0, 1]]"],
            "track: --area and --quad are not given together"
        ),
        (["evaluate", "/abs/doc.json"], "evaluate: missing --at <t>"),
        (["evaluate", "/abs/doc.json", "--at", "soon"], #"evaluate: --at "soon" is not a number of seconds"#),
        (["locate", "/abs/doc.json", "--at", "0"], "locate: missing --point <x,y>"),
        (["locate", "/abs/doc.json", "--at", "0", "--point", "1"], #"locate: --point "1" is not x,y"#),
        (["transcode", "/abs/in.png"], "transcode: missing -o <out>"),
        (
            ["transcode", "/abs/in.png", "-o", "/abs/out.jpg", "--quality", "best"],
            #"transcode: --quality "best" is not one of high, medium, low"#
        ),
        (["transcode", "/abs/in.mov", "-o", "/abs/out.mp4", "--codec", "av1"], #"transcode: --codec "av1" is not one of h264, hevc"#),
        (["transcode", "/abs/in.png", "-o", "/abs/out.jpg", "--max", "1.5"], #"transcode: --max "1.5" is not a whole number"#),
        (["transcode", "/abs/in.pdf", "-o", "/abs/out.png", "--scale", "0"], #"transcode: --scale "0" is not a number above 0"#),
        (
            ["transcode", "/abs/in.png", "-o", "/abs/out.png", "--color-space", "srgb-linear"],
            #"transcode: --color-space "srgb-linear" is not one of srgb, display-p3, rec2020, rec709, rec2100-pq, rec2100-hlg"#
        ),
        (
            ["ocr", "/abs/clip.mov", "--at", "1", "--color-space", "srgb-linear"],
            #"ocr: --color-space "srgb-linear" is not one of srgb, display-p3, rec2020, rec709, rec2100-pq, rec2100-hlg"#
        ),
        (
            ["track", "/abs/clip.mov", "--at", "0", "--area", "[0, 0, 1, 1]", "--color-space", "srgb-linear"],
            #"track: --color-space "srgb-linear" is not one of srgb, display-p3, rec2020, rec709, rec2100-pq, rec2100-hlg"#
        )
    ] as [([String], String)])
    func stopsOnArgument(
        arguments: [String],
        reason: String
    ) {
        // Given, When
        let code = sut.run(arguments)

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: \(reason)\n")
        #expect(sut.standardOutput.isEmpty)
    }

    // MARK: - Private
}
