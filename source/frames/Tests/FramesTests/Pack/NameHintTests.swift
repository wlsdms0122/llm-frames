//
//  NameHintTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Testing

@testable import Frames

@Suite("NameHint Tests")
struct NameHintTests {
    // MARK: - Property
    // The names two packs hold in one folder, `frames` and `shorts`.
    private let packs = [
        "frames": ["frames/arrow", "frames/bar", "frames/circle", "frames/diamond", "frames/line-arrow", "frames/square"],
        "shorts": ["shorts/hook"]
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a name of a pack that is there gets the nearest name that pack holds, where one is near, and its names",
        arguments: [
            ("frames/arow", "frames/arrow"),
            ("frames/circel", "frames/circle"),
            ("frames/line-arow", "frames/line-arrow"),
            ("shorts/hok", "shorts/hook")
        ]
    )
    func namesNearestInPack(
        name: String,
        nearest: String
    ) {
        // Given, When
        let sut = NameHint(name: name, packs: { packs.keys.sorted() }) { packs[$0] }

        // Then
        let pack = String(name.split(separator: "/")[0])
        #expect(sut == .pack(pack: pack, names: packs[pack] ?? [], nearest: nearest))
    }

    @Test("a name of a pack that is there and near none of its names gets its names alone", arguments: ["frames/dot", "frames/hook", "frames/a"])
    func listsPackWithoutNearest(name: String) {
        // Given, When
        let sut = NameHint(name: name, packs: { packs.keys.sorted() }) { packs[$0] }

        // Then
        #expect(sut == .pack(pack: "frames", names: packs["frames"] ?? [], nearest: nil))
    }

    @Test(
        "a name of a pack that is not there gets the nearest pack, where one is near, and the packs there are",
        arguments: [("frams/arrow", "frames"), ("short/hook", "shorts"), ("mine/arrow", nil), ("film/arrow", nil)] as [(String, String?)]
    )
    func namesNearestPack(
        name: String,
        nearest: String?
    ) {
        // Given, When
        let sut = NameHint(name: name, packs: { packs.keys.sorted() }) { packs[$0] }

        // Then
        let pack = String(name.split(separator: "/")[0])
        #expect(sut == .unknownPack(pack: pack, packs: ["frames", "shorts"], nearest: nearest))
    }

    @Test(
        "a name of another spelling gets the name frames ships that it is, or is near",
        arguments: [("circle", "frames/circle"), ("arow", "frames/arrow"), ("Bar", "frames/bar")]
    )
    func namesShipped(
        name: String,
        nearest: String
    ) {
        // Given, When
        let sut = NameHint(name: name, packs: { packs.keys.sorted() }) { packs[$0] }

        // Then
        #expect(sut == .spelling(nearest: nearest))
    }

    @Test("a path, or another spelling near nothing frames ships, gets no name", arguments: ["/abs/arrow.json", "spiral", "frames/arrow/more"])
    func givesNoName(name: String) {
        // Given, When
        let sut = NameHint(name: name, packs: { packs.keys.sorted() }) { packs[$0] }

        // Then
        #expect(sut == .spelling(nearest: nil))
    }

    @Test("the packs are listed only where the name's pack is not there")
    func listsPacksOnlyForUnknownPack() {
        // Given
        var listed = false

        // When
        _ = NameHint(name: "frames/arow", packs: { listed = true; return [] }) { packs[$0] }

        // Then
        #expect(!listed)
    }

    @Test("of two names as near, the first in name order is named")
    func namesFirstOfTies() {
        // Given, When
        let sut = NameHint(name: "frames/bat", packs: { ["frames"] }) { _ in ["frames/bag", "frames/bar"] }

        // Then
        #expect(sut == .pack(pack: "frames", names: ["frames/bag", "frames/bar"], nearest: "frames/bag"))
    }

    @Test("the text names the nearest, then what the pack holds, the packs there are, or the rule for names")
    func writesText() {
        // Given
        let rule = "A preset is named <pack>/<name>"

        // When
        let pack = NameHint.pack(pack: "shorts", names: ["shorts/hook"], nearest: "shorts/hook").text(things: "head presets", rule: rule)
        let empty = NameHint.pack(pack: "shorts", names: [], nearest: nil).text(things: "head presets", rule: rule)
        let nearPack = NameHint.unknownPack(pack: "short", packs: ["frames", "shorts"], nearest: "shorts").text(things: "head presets", rule: rule)
        let farPack = NameHint.unknownPack(pack: "mine", packs: ["frames", "shorts"], nearest: nil).text(things: "head presets", rule: rule)
        let noPacks = NameHint.unknownPack(pack: "mine", packs: [], nearest: nil).text(things: "head presets", rule: rule)
        let shipped = NameHint.spelling(nearest: "frames/circle").text(things: "head presets", rule: rule)
        let spelling = NameHint.spelling(nearest: nil).text(things: "head presets", rule: rule)

        // Then
        #expect(pack == #". Did you mean "shorts/hook"? The pack "shorts" holds the head presets shorts/hook"#)
        #expect(empty == #". The pack "shorts" holds no head presets"#)
        #expect(nearPack == #". Did you mean the pack "shorts"? There is no pack "short", and the packs are frames, shorts"#)
        #expect(farPack == #". There is no pack "mine", and the packs are frames, shorts"#)
        #expect(noPacks == #". There is no pack "mine", and there are no packs"#)
        #expect(shipped == #". Did you mean "frames/circle"? A preset is named <pack>/<name>"#)
        #expect(spelling == ". A preset is named <pack>/<name>")
    }

    // MARK: - Private
}
