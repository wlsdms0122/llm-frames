//
//  CommandUsageTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import FramesCommand

@Suite("CommandUsage Tests")
struct CommandUsageTests {
    // MARK: - Property
    private let sut = CommandUsage()

    // MARK: - Initializer
    // MARK: - Test
    @Test("the usage is the global options, then each command's name and synopsis in one column")
    func writesUsage() {
        // Given, When
        let text = sut.text

        // Then
        #expect(text == """
            frames [--theme <pack/name | /abs/theme.json>] [--decoder <name>] [--renderer <name>] [--mixer <name>] \
            [--encoder <name>] [--shaper <name>] [--tracker <name>] [--ocr <name>] <command> ...

            render    <document.json> -o <out.mov | out.mp4 | out.png> [--at <t>] [--deliver <out.mp4>] [--args <args.json>]
            still     <document.json> --at <t>[,<t>...] -o <out.png> [--args <args.json>]
            resolve   <document.json> -o <resolved.json> [--args <args.json>]
            timeline  <document.json> [--args <args.json>] [--json]
            evaluate  <document.json> --at <t> [--args <args.json>]
            locate    <document.json> --at <t> --point <x,y> [--args <args.json>]
            probe     <media> [--page <n>] [--json]
            loudness  <media | document.json> [--from <t>] [--to <t>] [--args <args.json>] [--json]
            ocr       <still | video> [--page <n>] [--at <t> | --from <t> --to <t> --step <s>] [--languages <tag>[,<tag>...]] [--color-space <name>] [--json]
            track     <video> --at <t> --area <area> [--to <t>] [--color-space <name>]
            extract   <video | document.json> <outdir> [--from <t>] [--to <t>] [--step 1]
            sheet     <video | document.json> -o <out.png> [--from <t>] [--to <t>] [--step 1] [--cols 6]
            transcode <in> [--page <n>] -o <out> [--quality high|medium|low] [--max <px> | --scale <s>] [--codec h264|hevc] [--color-space <name>]
            presets   [<kind>] [<name>]
            packs     [<pack>]
            theme

            """)
    }

    // MARK: - Private
}
