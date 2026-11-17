//
//  FrameExporterTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesCoreText
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Stills, sheets and extracted frames written by `FrameExporter` on the real decoder, renderer, encoder and shaper,
// read back through the decoder. Serialized, since AVAssetReader needs a free thread of the shared pool.
@Suite("FrameExporter Tests", .serialized)
struct FrameExporterTests {
    // MARK: - Property
    // H.264 subsamples and compresses colour, so a flat colour comes back to within a few steps.
    private let tolerance = 16.0 / 255
    private let colors: [[Double]] = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [128, 128, 128]]
    private let orange: [Double] = [255, 128, 0]
    private let blue: [Double] = [0, 0, 255]
    private let packs: TemporaryDirectory

    // MARK: - Initializer
    init() throws {
        packs = try TemporaryDirectory()
    }

    // MARK: - Test
    @Test("still draws the sequence frames at full size side by side, each with its time labelled on a band under it")
    func drawsStill() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        let sut = exporter()

        // When
        try sut.still(document, at: [0.2, 0.7], to: output.file("still.png"))

        // Then
        // The base theme's gap and padding are 5 at a width of 160.
        let still = try picture(at: output.file("still.png"))
        let band = still.height - 5 - 90 - 5
        #expect(still.width == 5 + 160 + 5 + 160 + 5)
        #expect(band > 0)
        #expect(still.isPixel(x: 85, y: 50, orange, tolerance: 1.0 / 255))
        #expect(still.isPixel(x: 250, y: 50, blue, tolerance: 1.0 / 255))
        #expect(labelPixels(in: still, x: 5..<165, y: 95..<(95 + band)) > 0)
        #expect(labelPixels(in: still, x: 170..<330, y: 95..<(95 + band)) > 0)
        #expect(still.isPixel(x: 6, y: 95 + band / 2, [255, 255, 255], tolerance: 1.0 / 255))
        #expect(try contents(of: output) == ["still.png"])
    }

    @Test("sheet lays a video's frames out on a grid, each cell at most 480 pixels on its longer side")
    func drawsVideoSheet() async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let video = try await self.video(in: media)
        let sut = exporter()

        // When
        try sut.sheet(.video(path: video), range: FrameRange(), columns: 2, to: output.file("sheet.png"))

        // Then
        // 640 x 360 cells shrink to 480 x 270, where the base theme's gap and padding are 16.
        let sheet = try picture(at: output.file("sheet.png"))
        let band = (sheet.height - 16 - 270 - 16 - 270 - 16) / 2
        let centres = [(256, 151), (752, 151), (256, 151 + 270 + band + 16), (752, 151 + 270 + band + 16)]
        #expect(sheet.width == 16 + 480 + 16 + 480 + 16)
        for (index, centre) in centres.enumerated() {
            #expect(
                sheet.isPixel(x: centre.0, y: centre.1, colors[index], tolerance: tolerance),
                "cell \(index): \(sheet.pixel(x: centre.0, y: centre.1))"
            )
        }
        #expect(labelPixels(in: sheet, x: 16..<496, y: 286..<(286 + band)) > 0)
    }

    @Test("a sheet of a document draws its frames as still does, and never enlarges a small frame")
    func drawsDocumentSheet() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        let sut = exporter()

        // When
        try sut.sheet(.document(document), range: FrameRange(step: 0.5), columns: 6, to: output.file("sheet.png"))

        // Then
        let sheet = try picture(at: output.file("sheet.png"))
        #expect(sheet.width == 5 + 160 + 5 + 160 + 5)
        #expect(sheet.isPixel(x: 85, y: 50, orange, tolerance: 1.0 / 255))
        #expect(sheet.isPixel(x: 250, y: 50, blue, tolerance: 1.0 / 255))
    }

    @Test("extract writes a video's frames over the range at full size, named by index, into a directory it makes")
    func extractsVideo() async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let video = try await self.video(in: media)
        let directory = output.file("nested/frames")
        let sut = exporter()

        // When
        let files = try sut.extract(.video(path: video), range: FrameRange(from: 1), to: directory)

        // Then
        #expect(files == ["0000.png", "0001.png", "0002.png"].map { "\(directory)/\($0)" })
        let names = try FileManager.default.contentsOfDirectory(atPath: directory).sorted()
        #expect(names == ["0000.png", "0001.png", "0002.png"])
        for (index, file) in files.enumerated() {
            let frame = try picture(at: file)
            #expect(frame.width == 640 && frame.height == 360)
            #expect(frame.isPixel(x: 320, y: 180, colors[index + 1], tolerance: tolerance), "\(file)")
        }
    }

    @Test("extract writes a document's frames at sequence times before the range's end, without labels")
    func extractsDocument() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        let sut = exporter()

        // When
        let range = FrameRange(from: 0.2, to: 0.8, step: 0.2)
        let files = try sut.extract(.document(document), range: range, to: output.path)

        // Then
        #expect(files.map { ($0 as NSString).lastPathComponent } == ["0000.png", "0001.png", "0002.png"])
        let frames = try files.map(picture(at:))
        #expect(frames.allSatisfy { $0.width == 160 && $0.height == 90 })
        #expect(frames.map { $0.isPixel(x: 80, y: 89, orange, tolerance: 1.0 / 255) } == [true, true, false])
        #expect(frames[2].isPixel(x: 80, y: 89, blue, tolerance: 1.0 / 255))
    }

    @Test("an image document has no times, so still, sheet and extract stop and write nothing")
    func refusesImageDocument() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let file = try image(in: media, named: "grey.png", color: [128, 128, 128])
        let document = try DocumentResolver().resolve(#"{ "kind": "image", "source": "\#(file)" }"#)
        let sut = exporter()

        // When, Then
        #expect(throws: ExportError.timelessDocument(kind: "image")) {
            try sut.still(document, at: [0], to: output.file("still.png"))
        }
        #expect(throws: ExportError.timelessDocument(kind: "image")) {
            try sut.sheet(.document(document), range: FrameRange(), columns: 6, to: output.file("sheet.png"))
        }
        #expect(throws: ExportError.timelessDocument(kind: "image")) {
            try sut.extract(.document(document), range: FrameRange(), to: output.file("frames"))
        }
        #expect(try contents(of: output).isEmpty)
    }

    @Test("a time outside the sequence, an output that is not a PNG and a file that is not a video stop")
    func refusesBadArguments() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        let still = media.file("orange.png")
        let sut = exporter()

        // When, Then
        #expect(throws: ExportError.timeOutside(option: "--at", time: 1, end: 1, kind: "sequence")) {
            try sut.still(document, at: [0.5, 1], to: output.file("still.png"))
        }
        #expect(throws: ExportError.outputExtension(path: output.file("sheet.jpg"))) {
            try sut.sheet(.document(document), range: FrameRange(), columns: 6, to: output.file("sheet.jpg"))
        }
        #expect(throws: ExportError.nonPositiveColumns(0)) {
            try sut.sheet(.document(document), range: FrameRange(), columns: 0, to: output.file("sheet.png"))
        }
        #expect(throws: ExportError.notVideo(path: still, kind: .image)) {
            try sut.extract(.video(path: still), range: FrameRange(), to: output.file("frames"))
        }
        #expect(throws: ExportError.missingMedia(path: media.file("none.mov"))) {
            try sut.extract(.video(path: media.file("none.mov")), range: FrameRange(), to: output.file("frames"))
        }
        #expect(try contents(of: output).isEmpty)
    }

    @Test("a document whose pinned file changed is refused before the directory is made")
    func refusesChangedFile() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let document = try sequence(in: media)
        _ = try image(in: media, named: "orange.png", color: [255, 129, 0])
        let sut = exporter()

        // When
        let error = #expect(throws: RenderError.self) {
            try sut.extract(.document(document), range: FrameRange(), to: output.file("frames"))
        }

        // Then
        guard case let .changedFile(_, place) = error else {
            Issue.record("refused with \(String(describing: error))")
            return
        }
        #expect(place == "storyline[0]")
        #expect(try contents(of: output).isEmpty)
    }

    // MARK: - Private
    private func exporter() -> FrameExporter {
        let decoder = AVFoundationDecoder()
        let directory = URL(fileURLWithPath: packs.path, isDirectory: true)

        return FrameExporter(
            decoder: decoder,
            renderer: QuartzRenderer(decoder: decoder),
            encoder: AVFoundationEncoder(),
            mediaFacts: decoder,
            shaper: CoreTextShaper(),
            library: ReferenceLibrary(packs: PackLibrary(installed: directory), mediaFacts: decoder)
        )
    }

    // An orange image for [0, 0.5) and a blue one for [0.5, 1), at 160 x 90 and 10 frames a second.
    private func sequence(in media: TemporaryDirectory) throws -> ResolvedDocument {
        let first = try image(in: media, named: "orange.png", color: orange)
        let second = try image(in: media, named: "blue.png", color: blue)

        return try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "media": "\#(first)", "duration": 0.5 }, { "media": "\#(second)", "duration": 0.5 } ] }
            """#)
    }

    // A 640 x 360 video whose frame i, shown from second i to i + 1, is `colors[i]`.
    private func video(in media: TemporaryDirectory) async throws -> String {
        let file = media.file("colors.mov")
        try await MovieWriter(size: Size(width: 640, height: 360), frameTimes: [0, 1, 2, 3], end: 4)
            .write(to: file) { canvas, index in
                canvas.fill(red: colors[index][0], green: colors[index][1], blue: colors[index][2])
            }

        return file
    }

    private func image(
        in directory: TemporaryDirectory,
        named name: String,
        color: [Double]
    ) throws -> String {
        let file = directory.file(name)
        try ImageWriter(size: Size(width: 160, height: 90)).write(to: file) { canvas in
            canvas.fill(red: color[0], green: color[1], blue: color[2])
        }

        return file
    }

    private func picture(at path: String) throws -> Bitmap {
        try AVFoundationDecoder().picture(of: MediaFile(path: path), atFrame: 0)
    }

    // The pixels in the area that show the base theme's accent, the colour behind a label.
    private func labelPixels(
        in bitmap: Bitmap,
        x columns: Range<Int>,
        y rows: Range<Int>
    ) -> Int {
        rows.flatMap { row in columns.map { column in (column, row) } }
            .filter { bitmap.isPixel(x: $0.0, y: $0.1, [237, 41, 41], tolerance: 2.0 / 255) }
            .count
    }

    private func contents(of directory: TemporaryDirectory) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }
}
