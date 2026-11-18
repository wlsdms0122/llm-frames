//
//  RepositoryPacksTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Testing

@testable import FramesCommand

// The packs kept in the repository under `packs/`, installed by copying them into a temporary `FRAMES_HOME` beside
// the pack frames ships, as a user installs them.
@Suite("RepositoryPacks Tests")
struct RepositoryPacksTests {
    // MARK: - Property
    // This file is `source/frames/Tests/FramesCommandTests/` in the repository.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let packs = root.appendingPathComponent("packs", isDirectory: true)
    private static let framesPack = root.appendingPathComponent(
        "source/frames/Sources/FramesCommand/Resources/packs/frames",
        isDirectory: true
    )

    private static let packNames = entries(in: packs)
    private static let themes = packNames.flatMap { pack in
        entries(in: packs.appendingPathComponent("\(pack)/themes", isDirectory: true))
            .filter { $0.hasSuffix(".json") }
            .map { "\(pack)/\(String($0.dropLast(".json".count)))" }
    }
    private static let filters = packNames.flatMap { pack in
        entries(in: packs.appendingPathComponent("\(pack)/presets/filter", isDirectory: true))
            .filter { $0.hasSuffix(".json") }
            .map { "\(pack)/\(String($0.dropLast(".json".count)))" }
    }
    private static let templates = packNames.flatMap { pack in
        entries(in: packs.appendingPathComponent("\(pack)/templates", isDirectory: true))
            .filter { $0.hasSuffix(".json") }
            .map { "\(pack)/\(String($0.dropLast(".json".count)))" }
    }
    private static let examples = packNames.flatMap { pack in
        entries(in: packs.appendingPathComponent("\(pack)/examples", isDirectory: true))
            .filter { $0.hasSuffix(".json") }
            .map { "\(pack)/examples/\($0)" }
    }

    // A sequence that needs no media, so a theme is merged and checked without reading anything else.
    private static let solid = #"""
        { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 1 } ] }
        """#

    // The screenshot the examples name `/path/to/checkout.png`: an order summary 1206 wide whose rows have their label
    // at the left and their value at the right, and a `Pay 42,000` button below them.
    private static let screenshot = #"""
        {
          "kind": "sequence",
          "format": { "size": [1206, 1500], "fps": 30, "background": "#F2F2F7" },
          "theme": {
            "colors": { "text": "#1C1C1E", "muted": "#8E8E93", "blue": "#0A64D6" },
            "styles": {
              "status": { "size": 40, "weight": "bold" },
              "heading": { "size": 64, "weight": "bold" },
              "row": { "size": 44 },
              "value": { "size": 44, "align": "right" },
              "strong": { "size": 48, "weight": "bold" },
              "strongValue": { "size": 48, "weight": "bold", "align": "right" },
              "note": { "size": 38, "color": "muted" },
              "button": { "size": 48, "weight": "bold", "color": "#FFFFFF", "align": "center" }
            }
          },
          "storyline": [
            { "solid": "#F2F2F7", "duration": 1,
              "connected": [
                { "title": "9:41", "style": "status", "width": 300, "anchor": "top-left", "position": [72, 40] },
                { "title": "Order summary", "style": "heading", "width": 1000, "anchor": "top-left", "position": [64, 160] },
                { "shape": "rect", "width": 1110, "height": 620, "anchor": "top-left", "position": [48, 290], "fill": "#FFFFFF", "radius": 28 },
                { "title": "Ship to", "style": "row", "width": 400, "anchor": "top-left", "position": [96, 340] },
                { "title": "jane@example.com", "style": "value", "width": 600, "anchor": "top-right", "position": [1110, 340] },
                { "shape": "rect", "width": 1014, "height": 2, "anchor": "top-left", "position": [96, 430], "fill": "#E5E5EA" },
                { "title": "Item total", "style": "row", "width": 400, "anchor": "top-left", "position": [96, 480] },
                { "title": "38,000", "style": "value", "width": 400, "anchor": "top-right", "position": [1110, 480] },
                { "title": "Shipping", "style": "row", "width": 400, "anchor": "top-left", "position": [96, 580] },
                { "title": "4,000", "style": "value", "width": 400, "anchor": "top-right", "position": [1110, 580] },
                { "shape": "rect", "width": 1014, "height": 2, "anchor": "top-left", "position": [96, 680], "fill": "#E5E5EA" },
                { "title": "Total", "style": "strong", "width": 400, "anchor": "top-left", "position": [96, 730] },
                { "title": "42,000", "style": "strongValue", "width": 400, "anchor": "top-right", "position": [1110, 730] },
                { "title": "Arrives in 2 days", "style": "note", "width": 1000, "anchor": "top-left", "position": [96, 820] },
                { "title": "Payment method", "style": "heading", "width": 1000, "anchor": "top-left", "position": [64, 980] },
                { "shape": "rect", "width": 1110, "height": 120, "anchor": "top-left", "position": [48, 1100], "fill": "#FFFFFF", "radius": 28 },
                { "title": "Card ending 4242", "style": "row", "width": 1000, "anchor": "top-left", "position": [96, 1134] },
                { "shape": "rect", "width": 1110, "height": 128, "anchor": "top-left", "position": [48, 1320], "fill": "blue", "radius": 32 },
                { "title": "Pay 42,000", "style": "button", "width": 1110, "anchor": "top", "position": [603, 1356] }
              ] }
          ]
        }
        """#

    // The recording the examples name `/path/to/checkout.mov`: the same summary 1280 by 720 for 3 seconds, where
    // `Add shipping` is clicked at 1 second, the `Shipping` row appears and `Total` turns from `38,000` to `42,000`, and
    // the list scrolls up from 1.8 to 2.6 seconds so that the email leaves the top edge.
    private static let recording = #"""
        {
          "kind": "sequence",
          "format": { "size": [1280, 720], "fps": 30, "background": "#FFFFFF" },
          "theme": {
            "colors": { "text": "#1C1C1E", "muted": "#8E8E93", "blue": "#0A64D6" },
            "styles": {
              "heading": { "size": 40, "weight": "bold" },
              "row": { "size": 30 },
              "strong": { "size": 32, "weight": "bold" },
              "note": { "size": 26, "color": "muted" },
              "button": { "size": 28, "weight": "bold", "color": "#FFFFFF" }
            }
          },
          "storyline": [ { "solid": "#FFFFFF", "duration": 3 } ],
          "clips": [
            { "id": "panel", "shape": "rect", "width": 1280, "height": 1000, "anchor": "top-left", "fill": "#FFFFFF",
              "keyframes": [ { "at": 1.8, "position": [0, 0], "ease": "ease-in-out" }, { "at": 2.6, "position": [0, -180] } ] },
            { "parent": "panel", "title": "Order summary", "style": "heading", "width": 800, "anchor": "top-left", "position": [80, 50] },
            { "parent": "panel", "title": "Ship to", "style": "row", "width": 400, "anchor": "top-left", "position": [80, 140] },
            { "parent": "panel", "title": "jane@example.com", "style": "row", "width": 600, "anchor": "top-right", "position": [1200, 140] },
            { "parent": "panel", "title": "Item total", "style": "row", "width": 400, "anchor": "top-left", "position": [80, 220] },
            { "parent": "panel", "title": "38,000", "style": "row", "width": 400, "anchor": "top-right", "position": [1200, 220] },
            { "parent": "panel", "at": [1, 3], "title": "Shipping", "style": "row", "width": 400, "anchor": "top-left", "position": [80, 290] },
            { "parent": "panel", "at": [1, 3], "title": "4,000", "style": "row", "width": 400, "anchor": "top-right", "position": [1200, 290] },
            { "parent": "panel", "shape": "rect", "width": 1120, "height": 2, "anchor": "top-left", "position": [80, 350], "fill": "#E5E5EA" },
            { "parent": "panel", "title": "Total", "style": "strong", "width": 400, "anchor": "top-left", "position": [80, 380] },
            { "parent": "panel", "at": [0, 1], "title": "38,000", "style": "strong", "width": 400, "anchor": "top-right", "position": [1200, 380] },
            { "parent": "panel", "at": [1, 3], "title": "42,000", "style": "strong", "width": 400, "anchor": "top-right", "position": [1200, 380] },
            { "parent": "panel", "id": "button", "shape": "rect", "width": 280, "height": 64, "anchor": "top-left", "position": [80, 470], "fill": "blue", "radius": 14 },
            { "parent": "button", "title": "Add shipping", "style": "button", "width": 280, "anchor": "center", "position": [140, 32] },
            { "parent": "panel", "title": "Arrives in 2 days", "style": "note", "width": 600, "anchor": "top-left", "position": [80, 580] },
            { "parent": "panel", "title": "Payment method", "style": "heading", "width": 800, "anchor": "top-left", "position": [80, 680] },
            { "parent": "panel", "title": "Card ending 4242", "style": "row", "width": 600, "anchor": "top-left", "position": [80, 770] },
            { "shape": "ellipse", "width": 26, "height": 26, "fill": "#00000099", "stroke": { "width": 3, "color": "#FFFFFF" },
              "keyframes": [ { "at": 0, "position": [760, 640], "ease": "ease-in-out" }, { "at": 0.9, "position": [220, 502] } ] }
          ]
        }
        """#

    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
        let shippedFrames = sut.shipped.appendingPathComponent("frames", isDirectory: true)
        try FileManager.default.removeItem(at: shippedFrames)
        try FileManager.default.copyItem(at: Self.framesPack, to: shippedFrames)
        for pack in Self.packNames {
            try FileManager.default.copyItem(
                at: Self.packs.appendingPathComponent(pack, isDirectory: true),
                to: sut.installed.appendingPathComponent(pack, isDirectory: true)
            )
        }
    }

    // MARK: - Test
    @Test("the repository keeps the forms demo, pr-evidence and shorts and the looks pack film")
    func holdsPacks() {
        // Given
        let expected = ["demo", "film", "pr-evidence", "shorts"]

        // When
        let packs = Self.packNames

        // Then
        #expect(packs == expected)
    }

    @Test("packs lists the pack frames ships and every installed pack with the name, version 1.0.0 and description its pack.json gives")
    func listsPacks() {
        // Given
        let expected: [[String?]] = (Self.packNames + ["frames"]).sorted().map { [$0, "1.0.0"] }

        // When
        let code = sut.run(["packs"])
        let fields = sut.standardOutput.split(separator: "\n").map { $0.components(separatedBy: "  ") }

        // Then
        #expect(code == 0, "\(sut.standardError)")
        #expect(fields.map { [$0.first, $0.dropFirst(2).first] } == expected)
        #expect(fields.allSatisfy { $0.count == 4 && !$0.contains("-") })
    }

    @Test("packs <pack> lists what the pack holds, every preset in it read and checked", arguments: packNames)
    func listsPackContents(_ pack: String) {
        // Given
        let head = "\(pack)  "

        // When
        let code = sut.run(["packs", pack])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        #expect(sut.standardOutput.hasPrefix(head))
    }

    @Test("every theme a pack holds merges on the base theme, its default presets found", arguments: themes)
    func mergesTheme(_ theme: String) {
        // Given
        let arguments = ["--theme", theme, "timeline", "-"]

        // When
        let code = sut.run(arguments, input: Self.solid)

        // Then
        #expect(code == 0, "\(sut.standardError)")
    }

    @Test("every filter a pack holds resolves on an adjustment clip, the LUTs it names read", arguments: filters)
    func resolvesFilter(_ filter: String) {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "solid": "#000000", "duration": 1 } ],
              "clips": [ { "adjust": "\#(filter)", "at": [0, 1] } ] }
            """#

        // When
        let code = sut.run(["resolve", "-", "-o", sut.directory.file("resolved.json")], input: document)

        // Then
        #expect(code == 0, "\(sut.standardError)")
    }

    @Test("every template a pack holds resolves as a storyline clip on the defaults of its params", arguments: templates)
    func resolvesTemplate(_ template: String) {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1920, 1080], "fps": 30 },
              "storyline": [ { "media": { "template": "\#(template)" } } ] }
            """#

        // When
        let code = sut.run(["resolve", "-", "-o", sut.directory.file("resolved.json")], input: document)

        // Then
        #expect(code == 0, "\(sut.standardError)")
    }

    @Test("every example a pack holds resolves once its media paths name a rendered screenshot and screen recording")
    func resolvesExamples() throws {
        // Given
        let media = sut.directory.file("media")
        try FileManager.default.createDirectory(atPath: media, withIntermediateDirectories: true)
        let screenshot = try sut.write(Self.screenshot, named: "screenshot.json")
        let recording = try sut.write(Self.recording, named: "recording.json")
        let screenshotCode = sut.run(["render", screenshot, "-o", "\(media)/checkout.png", "--at", "0"])
        try #require(screenshotCode == 0, "\(sut.standardError)")
        let recordingCode = sut.run(["render", recording, "-o", "\(media)/checkout.mov"])
        try #require(recordingCode == 0, "\(sut.standardError)")

        // When
        let failures = try Self.examples.compactMap { example in
            let document = try String(contentsOf: Self.packs.appendingPathComponent(example), encoding: .utf8)
                .replacingOccurrences(of: "/path/to/", with: "\(media)/")
            let code = sut.run(["resolve", "-", "-o", sut.directory.file("resolved.json")], input: document)

            return code == 0 ? nil : "\(example): \(sut.standardError)"
        }

        // Then
        #expect(!Self.examples.isEmpty)
        #expect(failures.isEmpty, "\(failures)")
    }

    // MARK: - Private
    // What a directory holds, in name order, without hidden files.
    private static func entries(in directory: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []

        return names.filter { !$0.hasPrefix(".") }.sorted()
    }
}
