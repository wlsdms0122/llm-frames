//
//  ShippedFilterPresetTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesTestMedia
import ImageIO
import Testing

@testable import Frames
@testable import FramesCommand

// The filters that ship with frames, read from the tool's own resources, and each drawn by `still` on a test picture
// whose width is the base theme's, so their theme lengths are drawn as written. Serialized, since each draws a frame.
@Suite("ShippedFilterPreset Tests", .serialized)
struct ShippedFilterPresetTests {
    // MARK: - Property
    private static let names: Set<String> = [
        "mono", "noir", "sepia", "warm", "cool", "vivid", "faded",
        "bright", "dark", "soft", "sharpen", "blur", "vignette", "pixelate"
    ]

    // The test picture, 1206 by 400, sRGB components from 0 to 255. Every patch lies on the 16 pixel grid.
    private static let size = Size(width: 1206, height: 400)
    private static let grey = 128.0
    private static let orange = (red: 200.0, green: 120.0, blue: 60.0)

    private let sut: PresetLibrary
    private let shell: TestShell

    // MARK: - Initializer
    init() throws {
        shell = try TestShell()
        let empty = URL(fileURLWithPath: shell.directory.file("empty"), isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        sut = PresetLibrary(
            packs: PackLibrary(installed: empty, shipped: CommandEnvironment.current.shippedPacks)
        )
        try FileManager.default.copyItem(
            at: CommandEnvironment.current.shippedPacks.appendingPathComponent("frames/presets/filter", isDirectory: true),
            to: shell.framesPresets.appendingPathComponent("filter", isDirectory: true)
        )
    }

    // MARK: - Test
    @Test("the shipped filters are exactly the 14 that FRAMES-16 names")
    func namesShippedFilters() throws {
        // Given, When
        let names = try sut.presets(of: .filter).map(\.name)

        // Then
        #expect(names.count == Self.names.count)
        #expect(Set(names) == Set(Self.names.map { "frames/\($0)" }))
    }

    @Test("every shipped filter reads, with a one line description and at least one operation", arguments: names)
    func readsShippedFilter(name: String) throws {
        // Given, When
        let preset = try #require(try sut.filter(named: "frames/\(name)"))

        // Then
        #expect(!preset.description.isEmpty)
        #expect(!preset.description.contains("\n"))
        #expect(!preset.operations.isEmpty)
    }

    @Test("mono turns a colour to grey")
    func monoTurnsGrey() throws {
        // Given, When
        let picture = try draw("mono")
        let orange = picture.color(column: 128, row: 104)

        // Then
        #expect(abs(orange.red - orange.green) <= 1)
        #expect(abs(orange.green - orange.blue) <= 1)
    }

    @Test("noir turns a colour to grey and spreads light and dark greys apart")
    func noirSpreadsGreys() throws {
        // Given, When
        let picture = try draw("noir")
        let orange = picture.color(column: 128, row: 104)
        let dark = picture.color(column: 304, row: 104)
        let light = picture.color(column: 400, row: 104)

        // Then
        #expect(abs(orange.red - orange.blue) <= 1)
        #expect(dark.green < 64 - 20)
        #expect(light.green > 192 + 20)
    }

    @Test("sepia turns a grey brown")
    func sepiaTurnsBrown() throws {
        // Given, When
        let grey = try draw("sepia").color(column: 603, row: 200)

        // Then
        #expect(grey.red > grey.green + 5)
        #expect(grey.green > grey.blue + 5)
    }

    @Test("warm moves a grey towards yellow and cool towards blue", arguments: [("warm", 1.0), ("cool", -1.0)])
    func shiftsTemperature(
        name: String,
        direction: Double
    ) throws {
        // Given, When
        let grey = try draw(name).color(column: 603, row: 200)

        // Then
        #expect((grey.red - grey.blue) * direction > 10)
    }

    @Test("vivid makes a colour stronger and faded makes it weaker", arguments: [("vivid", 1.0), ("faded", -1.0)])
    func changesSaturation(
        name: String,
        direction: Double
    ) throws {
        // Given
        let original = Self.orange.red - Self.orange.blue

        // When
        let orange = try draw(name).color(column: 128, row: 104)

        // Then
        #expect((orange.red - orange.blue - original) * direction > 10)
    }

    @Test("faded lifts black and dims white")
    func fadedLiftsBlack() throws {
        // Given, When
        let picture = try draw("faded")
        let black = picture.color(column: 80, row: 296)
        let white = picture.color(column: 176, row: 296)

        // Then
        #expect(black.green > 15)
        #expect(white.green < 245)
    }

    @Test("bright lightens a grey and dark darkens it", arguments: [("bright", 1.0), ("dark", -1.0)])
    func changesExposure(
        name: String,
        direction: Double
    ) throws {
        // Given, When
        let grey = try draw(name).color(column: 603, row: 200)

        // Then
        #expect((grey.green - Self.grey) * direction > 15)
    }

    @Test("soft lets white glow over the black beside it and leaves black far from it")
    func softGlows() throws {
        // Given, When
        let picture = try draw("soft")
        let near = picture.color(column: 120, row: 296)
        let far = picture.color(column: 36, row: 296)
        let grey = picture.color(column: 603, row: 200)

        // Then
        #expect(near.green > 10)
        #expect(far.green < near.green)
        #expect(abs(grey.green - Self.grey) <= 1)
    }

    @Test("sharpen steepens an edge and leaves a flat area")
    func sharpensEdge() throws {
        // Given, When
        let picture = try draw("sharpen")
        let darkSide = picture.color(column: 351, row: 104)
        let lightSide = picture.color(column: 352, row: 104)
        let flat = picture.color(column: 304, row: 104)

        // Then
        #expect(darkSide.green < 64 - 5)
        #expect(lightSide.green > 192 + 5)
        #expect(abs(flat.green - 64) <= 1)
    }

    @Test("blur softens an edge and leaves a flat area")
    func blursEdge() throws {
        // Given, When
        let picture = try draw("blur")
        let darkSide = picture.color(column: 351, row: 104)
        let lightSide = picture.color(column: 352, row: 104)
        let centre = picture.color(column: 603, row: 200)

        // Then
        #expect(darkSide.green > 64 + 20)
        #expect(lightSide.green < 192 - 20)
        #expect(abs(centre.green - Self.grey) <= 1)
    }

    @Test("vignette darkens the corners and leaves the centre")
    func darkensCorners() throws {
        // Given, When
        let picture = try draw("vignette")
        let corner = picture.color(column: 2, row: 2)
        let centre = picture.color(column: 603, row: 200)

        // Then
        #expect(corner.green < Self.grey - 20)
        #expect(abs(centre.green - Self.grey) <= 1)
    }

    @Test("pixelate fills each block of a fine checkerboard with its mean")
    func pixelatesBlocks() throws {
        // Given, When
        let picture = try draw("pixelate")
        let block = [(640, 64), (655, 64), (640, 79), (655, 79)].map { picture.color(column: $0.0, row: $0.1) }
        let other = picture.color(column: 880, row: 300)

        // Then
        #expect(block.allSatisfy { abs($0.green - block[0].green) <= 1 })
        #expect(abs(block[0].green - Self.grey) <= 3)
        #expect(abs(other.green - Self.grey) <= 3)
    }

    // MARK: - Private
    // Draws the test picture through the shipped filter `frames/<name>` with `still`, at the picture's own size.
    private func draw(_ name: String) throws -> RenderedPicture {
        let image = shell.directory.file("picture.png")
        if !FileManager.default.fileExists(atPath: image) {
            try writePicture(to: image)
        }
        let document = try shell.write(
            #"""
            { "kind": "sequence", "format": { "size": [1206, 400], "fps": 10 },
              "storyline": [ { "media": "\#(image)", "duration": 1, "filter": "frames/\#(name)" } ] }
            """#,
            named: "\(name).json"
        )
        let output = shell.directory.file("\(name).png")

        let code = shell.run(["still", document, "--at", "0.5", "-o", output])
        try #require(code == 0, "\(shell.standardError)")

        return try RenderedPicture(contentsOf: output)
    }

    // Grey, with an orange patch, a 64 and a 192 grey patch side by side, a black and a white patch side by side, and
    // a checkerboard of single pixels.
    private func writePicture(to path: String) throws {
        try ImageWriter(size: Self.size, opaque: true).write(to: path) { canvas in
            canvas.fill(red: Self.grey, green: Self.grey, blue: Self.grey)
            canvas.fill(
                Rectangle(x: 32, y: 32, width: 192, height: 144),
                red: Self.orange.red,
                green: Self.orange.green,
                blue: Self.orange.blue
            )
            canvas.fill(Rectangle(x: 256, y: 32, width: 96, height: 144), red: 64, green: 64, blue: 64)
            canvas.fill(Rectangle(x: 352, y: 32, width: 96, height: 144), red: 192, green: 192, blue: 192)
            canvas.fill(Rectangle(x: 32, y: 224, width: 96, height: 144), red: 0, green: 0, blue: 0)
            canvas.fill(Rectangle(x: 128, y: 224, width: 96, height: 144), red: 255, green: 255, blue: 255)
            canvas.fill(Rectangle(x: 640, y: 64, width: 256, height: 256), red: 255, green: 255, blue: 255)
            for row in 64..<320 {
                for column in 640..<896 where (row + column) % 2 == 0 {
                    canvas.fill(Rectangle(x: Double(column), y: Double(row), width: 1, height: 1), red: 0, green: 0, blue: 0)
                }
            }
        }
    }
}
