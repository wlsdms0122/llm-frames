//
//  UnknownReferenceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("UnknownReference Tests")
struct UnknownReferenceTests {
    // MARK: - Property
    private let directory: PackDirectory
    private let sut: PackLibrary

    // MARK: - Initializer
    // The installed pack `studio` holds two or more of every kind, the installed pack `empty` none, and the shipped
    // pack `frames` the head preset `frames/circle`. Every file is written as text that is not JSON, so a listing that
    // read one would stop.
    init() throws {
        directory = try PackDirectory()
        sut = directory.packs

        try directory.addPack("frames", in: directory.shipped)
        try directory.write("not read", to: directory.shipped.appendingPathComponent("frames/presets/head/circle.json"))
        try directory.addPack("empty")
        try directory.addPack("studio")
        for path in [
            "presets/head/hook.json", "presets/head/tick.json", "presets/head/notes.txt",
            "themes/dark.json", "themes/light.json", "themes/notes.txt",
            "templates/intro.json", "templates/outro.json",
            "luts/teal.cube", "luts/warm.cube", "luts/teal.json",
            "media/logo.png", "media/outro.mov", "media/shots/0001.png",
            "tools/autocut/tool.json", "tools/captions/tool.json", "tools/notes.txt"
        ] {
            try directory.write("not read", in: "studio", at: path)
        }
        try directory.write("not a pack", to: directory.installed.appendingPathComponent("notes.txt"))
    }

    // MARK: - Test
    @Test(
        "a name near one its pack holds names it and lists every name of its kind the pack holds",
        arguments: [
            (ReferenceKind.preset(.head), "studio/hok", #"unknown head preset "studio/hok". Did you mean "studio/hook"? The pack "studio" holds the head presets studio/hook, studio/tick"#),
            (.tool, "studio/autocat", #"unknown tool "studio/autocat". Did you mean "studio/autocut"? The pack "studio" holds the tools studio/autocut, studio/captions"#),
            (.theme, "studio/darkk", #"unknown theme "studio/darkk". Did you mean "studio/dark"? The pack "studio" holds the themes studio/dark, studio/light"#),
            (.template, "studio/itro", #"unknown template "studio/itro". Did you mean "studio/intro"? The pack "studio" holds the templates studio/intro, studio/outro"#),
            (.lut, "studio/tea", #"unknown LUT "studio/tea". Did you mean "studio/teal"? The pack "studio" holds the LUTs studio/teal, studio/warm"#),
            (.media, "studio/logo.pgn", #"unknown media "studio/logo.pgn". Did you mean "studio/logo.png"? The pack "studio" holds the media studio/logo.png, studio/outro.mov, studio/shots"#)
        ]
    )
    func namesNearestInPack(
        kind: ReferenceKind,
        name: String,
        message: String
    ) throws {
        // Given, When
        let reference = try sut.unknown(kind, named: name)

        // Then
        #expect(reference.description == message)
    }

    @Test(
        "a name near none its pack holds lists every name of its kind the pack holds",
        arguments: [
            (ReferenceKind.preset(.head), "studio/spiral", #"unknown head preset "studio/spiral". The pack "studio" holds the head presets studio/hook, studio/tick"#),
            (.tool, "studio/render", #"unknown tool "studio/render". The pack "studio" holds the tools studio/autocut, studio/captions"#),
            (.theme, "studio/neon", #"unknown theme "studio/neon". The pack "studio" holds the themes studio/dark, studio/light"#),
            (.template, "studio/credits", #"unknown template "studio/credits". The pack "studio" holds the templates studio/intro, studio/outro"#),
            (.lut, "studio/mono", #"unknown LUT "studio/mono". The pack "studio" holds the LUTs studio/teal, studio/warm"#),
            (.media, "studio/music.wav", #"unknown media "studio/music.wav". The pack "studio" holds the media studio/logo.png, studio/outro.mov, studio/shots"#)
        ]
    )
    func listsPackWithoutNearest(
        kind: ReferenceKind,
        name: String,
        message: String
    ) throws {
        // Given, When
        let reference = try sut.unknown(kind, named: name)

        // Then
        #expect(reference.description == message)
    }

    @Test(
        "a name in a pack that holds none of its kind says the pack holds none",
        arguments: [
            (ReferenceKind.preset(.transition), "empty/flash", #"unknown transition preset "empty/flash". The pack "empty" holds no transition presets"#),
            (.tool, "empty/autocut", #"unknown tool "empty/autocut". The pack "empty" holds no tools"#),
            (.theme, "empty/dark", #"unknown theme "empty/dark". The pack "empty" holds no themes"#),
            (.template, "empty/intro", #"unknown template "empty/intro". The pack "empty" holds no templates"#),
            (.lut, "empty/teal", #"unknown LUT "empty/teal". The pack "empty" holds no LUTs"#),
            (.media, "empty/logo.png", #"unknown media "empty/logo.png". The pack "empty" holds no media"#)
        ]
    )
    func saysEmptyPackHoldsNone(
        kind: ReferenceKind,
        name: String,
        message: String
    ) throws {
        // Given, When
        let reference = try sut.unknown(kind, named: name)

        // Then
        #expect(reference.description == message)
    }

    @Test(
        "a name of a pack that is not there names the nearest pack, where one is near, and lists the packs there are",
        arguments: [
            (ReferenceKind.preset(.head), "stuido/hook", #"unknown head preset "stuido/hook". Did you mean the pack "studio"? There is no pack "stuido", and the packs are empty, frames, studio"#),
            (.tool, "fram/find-text", #"unknown tool "fram/find-text". Did you mean the pack "frames"? There is no pack "fram", and the packs are empty, frames, studio"#),
            (.theme, "stuido/dark", #"unknown theme "stuido/dark". Did you mean the pack "studio"? There is no pack "stuido", and the packs are empty, frames, studio"#),
            (.template, "grade/intro", #"unknown template "grade/intro". There is no pack "grade", and the packs are empty, frames, studio"#),
            (.lut, "grade/teal", #"unknown LUT "grade/teal". There is no pack "grade", and the packs are empty, frames, studio"#),
            (.media, "studoi/logo.png", #"unknown media "studoi/logo.png". Did you mean the pack "studio"? There is no pack "studoi", and the packs are empty, frames, studio"#)
        ]
    )
    func listsPacksForUnknownPack(
        kind: ReferenceKind,
        name: String,
        message: String
    ) throws {
        // Given, When
        let reference = try sut.unknown(kind, named: name)

        // Then
        #expect(reference.description == message)
    }

    @Test(
        "a name of another spelling gives the rule of its kind, after the nearest name the pack frames holds",
        arguments: [
            (ReferenceKind.preset(.head), "circel", #"unknown head preset "circel". Did you mean "frames/circle"? A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#),
            (.tool, "/abs/autocut", #"unknown tool "/abs/autocut". A tool is named <pack>/<name>, and the ones frames ships are frames/<name>"#),
            (.theme, "dark", #"unknown theme "dark". A theme is named <pack>/<name> or by an absolute path"#),
            (.template, "studio/intro/more", #"unknown template "studio/intro/more". A template is named <pack>/<name> or by an absolute path"#),
            (.lut, "teal.cube", #"unknown LUT "teal.cube". A LUT is named <pack>/<name> or by an absolute path"#),
            (.media, "logo.png", #"unknown media "logo.png". Media is named <pack>/<name.ext>, <pack>/<dir> or by an absolute path"#)
        ]
    )
    func givesRuleForOtherSpelling(
        kind: ReferenceKind,
        name: String,
        message: String
    ) throws {
        // Given, When
        let reference = try sut.unknown(kind, named: name)

        // Then
        #expect(reference.description == message)
    }

    @Test(
        "an absolute path where nothing is there gets no hint",
        arguments: [
            (ReferenceKind.preset(.head), "/abs/hook.json", #"head preset "/abs/hook.json" is not there"#),
            (.theme, "/abs/dark.json", #"theme "/abs/dark.json" is not there"#),
            (.template, "/abs/intro.json", #"template "/abs/intro.json" is not there"#),
            (.media, "/abs/logo.png", #"media "/abs/logo.png" is not there"#)
        ]
    )
    func givesNoHintForPath(
        kind: ReferenceKind,
        name: String,
        message: String
    ) throws {
        // Given, When
        let reference = try sut.unknown(kind, named: name)

        // Then
        #expect(reference.description == message)
        #expect(reference.hint == nil)
    }

    @Test("a LUT named in a pack that is there but does not hold it stops with the hint where it is resolved")
    func hintsLookUpTableAtResolve() throws {
        // Given
        let resolver = PresetValueResolver(library: directory.library())

        // When
        let error = #expect(throws: ResolveError.self) {
            try resolver.lutFile("studio/tea", place: .root, kind: .clip(.media(.video)))
        }

        // Then
        #expect(error?.description == #"top level (video): unknown LUT "studio/tea". Did you mean "studio/teal"? The pack "studio" holds the LUTs studio/teal, studio/warm"#)
    }

    // MARK: - Private
}
